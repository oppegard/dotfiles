#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "optparse"
require "digest"
require "fileutils"

def parse_numeric(version)
  text = version.strip
  if text.length > 1 && (text[0] == "v" || text[0] == "V") && text[1] =~ /\d/
    text = text[1..-1]
  end
  parts = []
  current = +""
  text.each_char do |char|
    if char =~ /\d/
      current << char
      next
    end
    return nil if char != "." || current.empty?

    parts << current.to_i
    current = +""
  end
  return nil if current.empty?

  parts << current.to_i
  parts
end

def numeric_gt(old, new)
  left = parse_numeric(old)
  right = parse_numeric(new)
  return nil if left.nil? || right.nil?

  width = [left.length, right.length].max
  width.times do |index|
    lvalue = index < left.length ? left[index] : 0
    rvalue = index < right.length ? right[index] : 0
    return true if rvalue > lvalue
    return false if rvalue < lvalue
  end
  false
end

def list_is_forward(old, new)
  return nil if old.nil? || old.empty? || old.length != new.length

  saw_newer = false
  old.zip(new) do |left, right|
    next if left == right

    newer = numeric_gt(left, right)
    return nil if newer.nil?
    return false unless newer

    saw_newer = true
  end
  saw_newer
end

def update_kind(old, new)
  return "" if old.length != 1 || new.length != 1

  left = parse_numeric(old[0])
  right = parse_numeric(new[0])
  return "" if left.nil? || right.nil?
  return "major" if left[0] != right[0]

  left_minor = left.length > 1 ? left[1] : 0
  right_minor = right.length > 1 ? right[1] : 0
  return "minor" if left_minor != right_minor

  "patch"
end

def index_changes(changes)
  indexed = {}
  changes.each do |change|
    old = change.fetch("old_versions")
    versions = change.fetch("new_versions")
    next if old.empty? || versions.empty?

    indexed[change["name"]] = {
      "backend" => change["backend"],
      "old" => old,
      "new" => versions,
    }
  end
  indexed
end

def candidate_versions(name, bindings, change)
  old = change.fetch("old")
  new = change.fetch("new")
  abort "invalid version candidate for #{name}" unless old.length == new.length
  unless old.sort == bindings.map { |binding| binding.fetch("version") }.sort
    abort "stale version selection for #{name}"
  end
  bindings.map do |binding|
    choices = old.zip(new).filter_map { |from, to| to if from == binding.fetch("version") }.uniq
    abort "ambiguous version candidate for #{name}" unless choices.length == 1

    choices.first
  end
end

def plan_scope(scope, aged, fresh, snapshot)
  aged_by_name = index_changes(aged)
  fresh_by_name = index_changes(fresh)
  rows = []
  aged_by_name.each do |name, aged_change|
    fresh_change = fresh_by_name[name]
    bindings = snapshot.fetch(name) { abort "unknown planned tool #{name}" }
    old = bindings.map { |binding| binding.fetch("version") }
    aged_new = candidate_versions(name, bindings, aged_change)
    next unless list_is_forward(old, aged_new) == true

    fresh_new = candidate_versions(name, bindings, fresh_change) if fresh_change
    pending = []
    if fresh_new && list_is_forward(aged_new, fresh_new) == true
      pending = fresh_new
    end
    rows << {
      "scope" => scope,
      "name" => name,
      "backend" => aged_change["backend"],
      "old" => old,
      "adopted" => aged_new,
      "pending" => pending,
      "update" => update_kind(old, aged_new),
    }
  end
  { "scope" => scope, "rows" => rows }
end

def github_repo(backend)
  return nil if backend.nil? || backend.empty?

  repo = nil
  if backend.start_with?("github:")
    repo = backend.split(":", 2)[1]
  elsif backend.start_with?("packslip:github.com/")
    repo = backend.sub("packslip:github.com/", "")
  elsif backend.start_with?("aqua:")
    parts = backend.split(":", 2)[1].split("/")
    return nil if parts.length < 2 || parts[0].empty? || parts[1].empty?

    repo = "#{parts[0]}/#{parts[1]}"
  else
    return nil
  end
  return nil unless repo.count("/") == 1

  repo
end

def code_list(versions)
  versions.map { |version| "`#{version}`" }.join(", ")
end

def versions(row, side)
  row.fetch(side).map { |binding| binding.fetch("version") }
end

def backends(row, side)
  row.fetch(side).map { |binding| binding.fetch("backend") }
end

def version_changed?(row)
  versions(row, "before") != versions(row, "after")
end

def backend_changed?(row)
  backends(row, "before") != backends(row, "after")
end

def package_cell(row)
  repos = backends(row, "after").map { |backend| github_repo(backend) }.uniq
  name = row["name"].gsub("|", "\\|").gsub("\n", " ")
  return name if repos.length != 1 || repos[0].nil?

  "[#{name}](https://github.com/#{repos[0]})"
end

def change_cell(row)
  "#{code_list(versions(row, "before"))} → #{code_list(versions(row, "after"))}"
end

def combine_rows(rows)
  grouped = []
  index = {}
  rows.each do |row|
    key = [row["name"], row["before"], row["after"], row["pending"]]
    existing = index[key]
    if existing
      existing["scopes"] << row["scope"] unless existing["scopes"].include?(row["scope"])
      next
    end

    copy = row.dup
    copy["scopes"] = [row["scope"]]
    index[key] = copy
    grouped << copy
  end
  grouped
end

def scope_cell(row)
  labels = { "project" => "Project", "global" => "Global" }
  order = { "project" => 0, "global" => 1 }
  row["scopes"].sort_by { |scope| order.fetch(scope, 9) }.map { |scope| labels.fetch(scope, scope) }.join(", ")
end

def title_for(rows)
  labels = rows.group_by { |row| row["name"] }.map do |name, tool_rows|
    upgraded = tool_rows.find { |row| version_changed?(row) }
    upgraded ? "#{name} #{versions(upgraded, "after")[0]}" : "#{name} backend"
  end
  return "chore(mise): update tools" if labels.empty?

  shown = labels.take(2).join(", ")
  extra = labels.length > 2 ? " (+#{labels.length - 2})" : ""
  "chore(mise): update #{shown}#{extra}"
end

def render(plans, age)
  rows = combine_rows(plans.flat_map { |plan| plan.fetch("rows") })
  upgrades = rows.select { |row| version_changed?(row) }
  migrations = rows.select { |row| backend_changed?(row) }
  show_pending = upgrades.any? { |row| !row["pending"].empty? }
  lines = ["This PR contains the following updates:", ""]
  unless upgrades.empty?
    headers = ["Package", "Type", "Update", "Change"]
    headers << "Pending" if show_pending
    headers << "Scope"
    lines << "| #{headers.join(" | ")} |"
    lines << "|#{Array.new(headers.length, "---").join("|")}|"
    upgrades.each do |row|
      cells = [package_cell(row), "tools", update_kind(versions(row, "before"), versions(row, "after")), change_cell(row)]
      cells << code_list(row["pending"]) if show_pending
      cells << scope_cell(row)
      lines << "| #{cells.join(" | ")} |"
    end
  end
  unless migrations.empty?
    lines += ["", "### Backend changes", "", "| Package | Version | Old backend | New backend | Scope |", "|---|---|---|---|---|"]
    migrations.each do |row|
      version = version_changed?(row) ? change_cell(row) : code_list(versions(row, "after"))
      cells = [package_cell(row), version, code_list(backends(row, "before")), code_list(backends(row, "after")), scope_cell(row)]
      lines << "| #{cells.join(" | ")} |"
    end
  end
  lines << "No tool changes." if rows.empty?
  lines += [
    "", "---", "",
    "The age window is `#{age}` from `minimum_release_age`.",
    "Release notes name the version this pull request locks.", "",
    "Mise does not refuse a major bump of a `latest` or `lts` request.",
    "A prefix request such as `2` or `1.27` stays inside that prefix.",
    "This job does not add a major filter.", "",
    "The updater does not roll a locked version backward when that version is still inside the age window.",
    "MISE_SAFE=1 hides an idiomatic Go pin, so this job does not bump it.",
  ]
  notes = {}
  upgrades.each do |row|
    row["before"].zip(row["after"]).each do |old, binding|
      next if old["version"] == binding["version"]

      repo = github_repo(binding["backend"])
      next if repo.nil?

      key = [row["name"], repo, binding["version"]]
      notes[key] ||= { "scopes" => [] }
      notes[key]["scopes"] |= row["scopes"]
    end
  end
  unless notes.empty?
    lines += ["", "### Release notes", ""]
    notes.each do |(name, repo, version), entry|
      lines << "- [#{name} #{version}](https://github.com/#{repo}/releases) (#{scope_cell(entry)})"
    end
  end
  [title_for(rows), "#{lines.join("\n")}\n"]
end

def canonical_lock(path)
  File.join(File.realpath(File.dirname(path)), File.basename(path))
end

def read_changes(path, lock)
  data = JSON.parse(File.read(path))
  abort "#{path} must be a JSON array" unless data.is_a?(Array)

  selected = canonical_lock(lock)
  data.select do |change|
    candidate = change["lockfile"]
    abort "invalid candidate lockfile" unless candidate.is_a?(String) && !candidate.empty?

    canonical_lock(candidate) == selected
  end
end

def require_option(options, key)
  value = options[key]
  abort "missing --#{key.to_s.tr("_", "-")}" if value.nil? || value.empty?
end

def command_plan(argv)
  options = command_options(argv, %i[scope aged fresh snapshot lock out])
  plan = plan_scope(
    options[:scope],
    read_changes(options[:aged], options[:lock]),
    read_changes(options[:fresh], options[:lock]),
    JSON.parse(File.read(options[:snapshot]))
  )
  File.write(options[:out], JSON.generate(plan))
  plan["rows"].each do |row|
    puts row["name"]
  end
end

def command_render(argv)
  options = { plans: [] }
  parser = OptionParser.new do |opts|
    opts.on("--plan PATH") { |value| options[:plans] << value }
    opts.on("--age AGE") { |value| options[:age] = value }
    opts.on("--title-file PATH") { |value| options[:title_file] = value }
    opts.on("--body-file PATH") { |value| options[:body_file] = value }
  end
  parser.parse!(argv)
  abort "missing --plan" if options[:plans].empty?
  %i[age title_file body_file].each { |key| require_option(options, key) }
  plans = options[:plans].map { |path| JSON.parse(File.read(path)) }
  title, body = render(plans, options[:age])
  File.write(options[:title_file], "#{title}\n")
  File.write(options[:body_file], body)
end

def command_options(argv, keys, flags = [])
  options = {}
  OptionParser.new do |parser|
    keys.each { |key| parser.on("--#{key.to_s.tr("_", "-")} VALUE") { |value| options[key] = value } }
    flags.each { |flag| parser.on("--#{flag}") { options[flag] = true } }
  end.parse!(argv)
  keys.each { |key| require_option(options, key) }
  abort "unexpected arguments: #{argv.join(" ")}" unless argv.empty?

  options
end

def read_snapshot(path)
  JSON.parse(File.read(path))
end

def command_snapshot(argv)
  options = command_options(argv, %i[lock out])
  require "bundler/inline"
  gemfile do
    source "https://rubygems.org"
    gem "toml-rb", "= 6.0.0", require: "toml-rb"
  end
  document = TomlRB.load_file(options[:lock])
  abort "unsupported lockfile format" unless document["lockfile_version"] == 3

  tools = document.fetch("tools")
  tools.each do |name, bindings|
    abort "invalid bindings for #{name}" unless bindings.is_a?(Array) && !bindings.empty?

    bindings.each do |binding|
      %w[version backend].each do |field|
        value = binding[field]
        abort "invalid #{field} for #{name}" unless value.is_a?(String) && !value.empty? && !value.match?(/[\n\r]/)
      end
      specifiers = binding.fetch("specifiers", [])
      abort "invalid specifiers for #{name}" unless specifiers.is_a?(Array) && specifiers.all? { |value| value.is_a?(String) }
    end
    abort "invalid tool name" if name.empty? || name.match?(/[\n\r]/)
  end
  File.write(options[:out], JSON.generate(tools))
end

def match_bindings(name, before, after)
  abort "binding count changed for #{name}" unless before.length == after.length
  return before.zip(after) if before.length == 1

  indices = [before, after].map do |bindings|
    indexed = {}
    bindings.each do |binding|
      identity = binding.fetch("specifiers", []).sort
      abort "ambiguous request identity for #{name}" if identity.empty? || indexed.key?(identity)

      indexed[identity] = binding
    end
    indexed
  end
  abort "request identities changed for #{name}" unless indices[0].keys.sort == indices[1].keys.sort

  indices[0].map { |identity, binding| [binding, indices[1].fetch(identity)] }
end

def same_tools(before, after)
  abort "lock tool set changed" unless before.keys.sort == after.keys.sort
end

def command_verify_migration(argv)
  options = command_options(argv, %i[before after])
  before = read_snapshot(options[:before])
  after = read_snapshot(options[:after])
  same_tools(before, after)
  before.each do |name, bindings|
    match_bindings(name, bindings, after.fetch(name)).each do |old, new|
      abort "backend migration changed version for #{name}" unless old["version"] == new["version"]
    end
  end
end

def binding_record(binding)
  { "version" => binding.fetch("version"), "backend" => binding.fetch("backend"), "specifiers" => binding.fetch("specifiers", []).sort }
end

def command_reconcile(argv)
  options = command_options(argv, %i[scope before migrated after plan fresh lock out])
  before, migrated, after = %i[before migrated after].map { |key| read_snapshot(options[key]) }
  same_tools(before, migrated)
  same_tools(migrated, after)
  selections = read_snapshot(options[:plan]).fetch("rows").to_h { |row| [row.fetch("name"), row] }
  fresh = index_changes(read_changes(options[:fresh], options[:lock]))
  rows = []
  before.each do |name, original|
    migration_pairs = match_bindings(name, original, migrated.fetch(name))
    final_pairs = match_bindings(name, migrated.fetch(name), after.fetch(name))
    finals = final_pairs.to_h { |left, right| [left, right] }
    final = migration_pairs.map { |_, middle| finals.fetch(middle) }
    selection = selections[name]
    middle_bindings = migrated.fetch(name)
    selected = selection ? selection.fetch("adopted") : middle_bindings.map { |binding| binding.fetch("version") }
    by_binding = middle_bindings.zip(selected).to_h
    expected = migration_pairs.map { |_, middle| by_binding.fetch(middle) }
    abort "unexpected final version for #{name}" unless final.map { |binding| binding.fetch("version") } == expected

    migration_pairs.zip(final).each do |(old, middle), adopted|
      abort "backend migration changed version for #{name}" unless old["version"] == middle["version"]
      abort "unexpected final backend for #{name}" unless middle["backend"] == adopted["backend"]
    end
    pending = []
    fresh_versions = candidate_versions(name, middle_bindings, fresh[name]) if fresh[name]
    if fresh_versions
      fresh_by_binding = middle_bindings.zip(fresh_versions).to_h
      ordered_fresh = migration_pairs.map { |_, middle| fresh_by_binding.fetch(middle) }
      pending = ordered_fresh if list_is_forward(expected, ordered_fresh) == true
    end
    ordered = original.zip(final, pending).sort_by { |old, _, _| old.fetch("specifiers", []).sort }
    row = {
      "scope" => options[:scope], "name" => name,
      "before" => ordered.map { |old, _, _| binding_record(old) },
      "after" => ordered.map { |_, adopted, _| binding_record(adopted) },
      "pending" => pending.empty? ? [] : ordered.map { |_, _, version| version },
    }
    rows << row if version_changed?(row) || backend_changed?(row)
  end
  File.write(options[:out], JSON.generate({ "scope" => options[:scope], "rows" => rows }))
end

ARTIFACT_PATHS = %w[mise.lock .mise/locks files/home/.config/mise/mise.lock files/home/.config/mise/locks].freeze

def reject_link(root, relative)
  path = root
  relative.split("/").each do |part|
    path = File.join(path, part)
    abort "refusing artifact symlink #{path}" if File.symlink?(path)
  end
end

def artifact_hashes(root)
  files = {}
  ARTIFACT_PATHS.each do |relative|
    reject_link(root, relative)
    path = File.join(root, relative)
    paths = File.directory?(path) ? Dir.glob("#{path}/**/*", File::FNM_DOTMATCH) : [path]
    paths.sort.each do |file|
      name = file.delete_prefix("#{root}/")
      reject_link(root, name)
      next if File.directory?(file) || !File.exist?(file)

      abort "artifact must be a regular file: #{file}" unless File.file?(file)

      files[name] = Digest::SHA256.file(file).hexdigest
    end
  end
  files
end

def command_artifacts(argv)
  options = command_options(argv, %i[source staged manifest], %i[publish])
  source = artifact_hashes(options[:source])
  staged = artifact_hashes(options[:staged])
  unless options[:publish]
    abort "source artifacts changed while copying" unless source == staged

    File.write(options[:manifest], JSON.generate(source))
    return
  end
  original = read_snapshot(options[:manifest])
  abort "source artifacts changed during update" unless source == original

  (source.keys | staged.keys).each do |relative|
    next if source[relative] == staged[relative]

    target = File.join(options[:source], relative)
    if staged.key?(relative)
      FileUtils.mkdir_p(File.dirname(target))
      temporary = "#{target}.mise-update-#{Process.pid}"
      begin
        FileUtils.cp(File.join(options[:staged], relative), temporary)
        File.rename(temporary, target)
      ensure
        FileUtils.rm_f(temporary)
      end
    else
      File.unlink(target)
    end
  end
end

def main(argv)
  command = argv.shift
  case command
  when "plan"
    command_plan(argv)
  when "render"
    command_render(argv)
  when "snapshot"
    command_snapshot(argv)
  when "verify-migration"
    command_verify_migration(argv)
  when "reconcile"
    command_reconcile(argv)
  when "artifacts"
    command_artifacts(argv)
  else
    abort "usage: mise_lock_plan.rb plan|snapshot|verify-migration|reconcile|artifacts|render ..."
  end
end

main(ARGV) if $PROGRAM_NAME == __FILE__
