#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "optparse"

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
    versions = change["new_versions"] || []
    next if versions.empty?

    indexed[change["name"]] = {
      "backend" => change["backend"],
      "old" => change["old_versions"] || [],
      "new" => versions,
    }
  end
  indexed
end

def plan_scope(scope, aged, fresh)
  aged_by_name = index_changes(aged)
  fresh_by_name = index_changes(fresh)
  rows = []
  aged_by_name.each do |name, aged_change|
    fresh_change = fresh_by_name[name]
    old = aged_change["old"]
    aged_new = aged_change["new"]
    next unless list_is_forward(old, aged_new) == true

    fresh_new = fresh_change && fresh_change["new"]
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

def package_cell(row)
  repo = github_repo(row["backend"])
  name = row["name"]
  return name if repo.nil?

  "[#{name}](https://github.com/#{repo})"
end

def change_cell(row)
  "#{code_list(row["old"])} → #{code_list(row["adopted"])}"
end

def pending_cell(row)
  return "" if row["pending"].empty?

  code_list(row["pending"])
end

def combine_rows(rows)
  grouped = []
  index = {}
  rows.each do |row|
    key = [row["name"], row["backend"], row["old"], row["adopted"], row["pending"], row["update"]]
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
  labels = []
  rows.each do |row|
    label = "#{row["name"]} #{row["adopted"][0]}"
    labels << label unless labels.include?(label)
  end
  return "chore(mise): update tool locks" if labels.empty?

  shown = labels.take(2).join(", ")
  extra = labels.length > 2 ? " (+#{labels.length - 2})" : ""
  "chore(mise): update #{shown}#{extra}"
end

def table_row(row, show_pending)
  cells = [package_cell(row), "tools", row["update"], change_cell(row)]
  cells << pending_cell(row) if show_pending
  cells << scope_cell(row)
  "| #{cells.join(" | ")} |"
end

def render(plans, age)
  rows = combine_rows(plans.flat_map { |plan| plan["rows"] })
  show_pending = rows.any? { |row| !row["pending"].empty? }
  if show_pending
    header = "| Package | Type | Update | Change | Pending | Scope |"
    separator = "|---|---|---|---|---|---|"
    blank = "| | | | | | |"
  else
    header = "| Package | Type | Update | Change | Scope |"
    separator = "|---|---|---|---|---|"
    blank = "| | | | | |"
  end
  lines = [
    "This PR contains the following updates:",
    "",
    header,
    separator,
  ]
  lines << blank if rows.empty?
  rows.each { |row| lines << table_row(row, show_pending) }
  lines += [
    "",
    "---",
    "",
    "The age window is `#{age}` from `minimum_release_age`.",
    "Release notes name the version this pull request locks.",
    "",
    "Mise does not refuse a major bump of a `latest` or `lts` request.",
    "A prefix request such as `2` or `1.27` stays inside that prefix.",
    "This job does not add a major filter.",
    "",
    "The updater does not roll a locked version backward when that version is still inside the age window.",
    "MISE_SAFE=1 hides an idiomatic Go pin, so this job does not bump it.",
  ]
  entries = []
  seen = {}
  rows.each do |row|
    repo = github_repo(row["backend"])
    next if repo.nil?

    version = row["adopted"][0]
    key = [row["name"], repo, version]
    existing = seen[key]
    if existing
      row["scopes"].each do |scope|
        existing["scopes"] << scope unless existing["scopes"].include?(scope)
      end
      next
    end

    entry = {
      "name" => row["name"],
      "repo" => repo,
      "version" => version,
      "scopes" => row["scopes"].dup,
    }
    seen[key] = entry
    entries << entry
  end
  notes = entries.map do |entry|
    "- [#{entry["name"]} #{entry["version"]}](https://github.com/#{entry["repo"]}/releases) (#{scope_cell(entry)})"
  end
  unless notes.empty?
    lines += ["", "### Release notes", ""]
    lines += notes
  end
  [title_for(rows), "#{lines.join("\n")}\n"]
end

def read_changes(path)
  data = JSON.parse(File.read(path))
  abort "#{path} must be a JSON array" unless data.is_a?(Array)

  data
end

def require_option(options, key)
  value = options[key]
  abort "missing --#{key.to_s.tr("_", "-")}" if value.nil? || value.empty?
end

def command_plan(argv)
  options = {}
  parser = OptionParser.new do |opts|
    opts.on("--scope SCOPE") { |value| options[:scope] = value }
    opts.on("--aged PATH") { |value| options[:aged] = value }
    opts.on("--fresh PATH") { |value| options[:fresh] = value }
    opts.on("--out PATH") { |value| options[:out] = value }
  end
  parser.parse!(argv)
  %i[scope aged fresh out].each { |key| require_option(options, key) }
  plan = plan_scope(
    options[:scope],
    read_changes(options[:aged]),
    read_changes(options[:fresh])
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

def main(argv)
  command = argv.shift
  case command
  when "plan"
    command_plan(argv)
  when "render"
    command_render(argv)
  else
    abort "usage: mise_lock_plan.rb plan|render ..."
  end
end

main(ARGV) if $PROGRAM_NAME == __FILE__
