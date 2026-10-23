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

def plan_scope(scope, aged, fresh, emergency_tool, age)
  aged_by_name = index_changes(aged)
  fresh_by_name = index_changes(fresh)
  names = []
  seen = {}
  (aged_by_name.keys + fresh_by_name.keys).each do |name|
    next if seen[name]

    seen[name] = true
    names << name
  end
  rows = []
  names.each do |name|
    aged_change = aged_by_name[name]
    fresh_change = fresh_by_name[name]
    source = aged_change || fresh_change
    old = source["old"]
    backend = source["backend"]
    fresh_new = fresh_change && fresh_change["new"]
    aged_new = aged_change && aged_change["new"]
    adopted = nil
    write_age = ""
    if !emergency_tool.empty? && name == emergency_tool && fresh_new && list_is_forward(old, fresh_new) == true
      adopted = fresh_new
      write_age = "0s"
    elsif aged_new && list_is_forward(old, aged_new) == true
      adopted = aged_new
      write_age = age
    end
    kept = adopted.nil? ? old : adopted
    pending = nil
    if fresh_new && fresh_new != kept && list_is_forward(kept, fresh_new) == true
      pending = fresh_new
    end
    next if adopted.nil? && pending.nil?

    compared = adopted || pending || []
    rows << {
      "scope" => scope,
      "name" => name,
      "backend" => backend,
      "old" => old,
      "adopted" => adopted || [],
      "pending" => pending || [],
      "update" => update_kind(old, compared),
      "age" => write_age,
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
  old = code_list(row["old"])
  return "#{old} → #{code_list(row["adopted"])}" unless row["adopted"].empty?

  old
end

def pending_cell(row)
  return "" if row["pending"].empty?

  code_list(row["pending"])
end

def title_for(rows)
  adopted = rows.select { |row| !row["adopted"].empty? }
  pending = rows.select { |row| !row["pending"].empty? }
  chosen = adopted.empty? ? pending : adopted
  field = adopted.empty? ? "pending" : "adopted"
  prefix = adopted.empty? ? "pending" : "update"
  if chosen.empty?
    return "chore(mise): update tool locks"
  end

  labels = []
  chosen.each do |row|
    label = "#{row["name"]} #{row[field][0]}"
    labels << label unless labels.include?(label)
  end
  shown = labels.take(2).join(", ")
  extra = labels.length > 2 ? " (+#{labels.length - 2})" : ""
  "chore(mise): #{prefix} #{shown}#{extra}"
end

def render(plans, age, emergency_tool)
  rows = plans.flat_map { |plan| plan["rows"] }
  lines = [
    "This PR contains the following updates:",
    "",
    "| Package | Type | Update | Change | Pending |",
    "|---|---|---|---|---|",
  ]
  lines << "| | | | | |" if rows.empty?
  rows.each do |row|
    lines << "| #{package_cell(row)} | tools | #{row["update"]} | #{change_cell(row)} | #{pending_cell(row)} |"
  end
  lines += [
    "",
    "---",
    "",
    "The age window is `#{age}` from `minimum_release_age`.",
    "A pending version is a newer release that this run will not lock.",
    "Mise lock JSON has no pending field.",
    "Pending is the `0s` resolution when that version is newer than the one this PR locks.",
    "",
    "Mise does not refuse a major bump of a `latest` or `lts` request.",
    "A prefix request such as `2` or `1.27` stays inside that prefix.",
    "This job does not add a major filter.",
    "",
    "The updater does not roll a locked version backward when that version is still inside the age window.",
    "MISE_SAFE=1 hides an idiomatic Go pin, so this job does not bump it.",
  ]
  unless emergency_tool.empty?
    lines += [
      "",
      "Emergency bump for `#{emergency_tool}` uses `--minimum-release-age 0s`.",
    ]
  end
  notes = []
  rows.each do |row|
    repo = github_repo(row["backend"])
    next if repo.nil?

    version = (row["adopted"].empty? ? nil : row["adopted"]) ||
      (row["pending"].empty? ? nil : row["pending"]) ||
      row["old"]
    version = version[0]
    state = !row["pending"].empty? && row["adopted"].empty? ? "pending" : row["scope"]
    notes << "- [#{row["name"]} #{version}](https://github.com/#{repo}/releases) (#{state})"
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
  options = { emergency_tool: "" }
  parser = OptionParser.new do |opts|
    opts.on("--scope SCOPE") { |value| options[:scope] = value }
    opts.on("--aged PATH") { |value| options[:aged] = value }
    opts.on("--fresh PATH") { |value| options[:fresh] = value }
    opts.on("--age AGE") { |value| options[:age] = value }
    opts.on("--emergency-tool TOOL") { |value| options[:emergency_tool] = value }
    opts.on("--out PATH") { |value| options[:out] = value }
  end
  parser.parse!(argv)
  %i[scope aged fresh age out].each { |key| require_option(options, key) }
  plan = plan_scope(
    options[:scope],
    read_changes(options[:aged]),
    read_changes(options[:fresh]),
    options[:emergency_tool],
    options[:age]
  )
  File.write(options[:out], JSON.generate(plan))
  plan["rows"].each do |row|
    next if row["adopted"].empty?

    puts "#{row["name"]} #{row["age"]}"
  end
end

def command_render(argv)
  options = { plans: [], emergency_tool: "" }
  parser = OptionParser.new do |opts|
    opts.on("--plan PATH") { |value| options[:plans] << value }
    opts.on("--age AGE") { |value| options[:age] = value }
    opts.on("--emergency-tool TOOL") { |value| options[:emergency_tool] = value }
    opts.on("--title-file PATH") { |value| options[:title_file] = value }
    opts.on("--body-file PATH") { |value| options[:body_file] = value }
  end
  parser.parse!(argv)
  abort "missing --plan" if options[:plans].empty?
  %i[age title_file body_file].each { |key| require_option(options, key) }
  plans = options[:plans].map { |path| JSON.parse(File.read(path)) }
  title, body = render(plans, options[:age], options[:emergency_tool])
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
