# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "open3"
require "tmpdir"

class MacosDefaultsAuditTest < Minitest::Test
  SCRIPT = File.expand_path("../bin/macos-defaults-audit", __dir__)
  FIXTURES = File.expand_path("fixtures/macos-defaults-audit", __dir__)

  def test_compare_classifies_and_renders_live_snapshot_differences
    Dir.mktmpdir do |directory|
      stdout, stderr, status = Open3.capture3(
        "/usr/bin/ruby", SCRIPT, "compare",
        "--baseline", File.join(FIXTURES, "baseline.json"),
        "--current", File.join(FIXTURES, "current.json"),
        "--output", directory
      )

      assert status.success?, "#{stdout}\n#{stderr}"
      report = JSON.parse(File.read(File.join(directory, "defaults-diff.json")))
      classifications = report.fetch("differences").to_h { |entry| [entry.fetch("key"), entry.fetch("classification")] }

      assert_equal "mise_candidate", classifications.fetch("NewScalar")
      assert_equal "mise_candidate", classifications.fetch("ChangedType")
      assert_equal "unmanaged_absent", classifications.fetch("RemovedScalar")
      assert_equal "unsupported_host_scoped", classifications.fetch("HostOnly")
      assert_equal "unsupported_complex_value", classifications.fetch("Complex")

      candidates = File.read(File.join(directory, "mise-candidates.toml"))
      assert_includes candidates, "NewScalar"
      refute_includes candidates, "HostOnly"
      refute_includes candidates, "Complex"

      markdown = File.read(File.join(directory, "defaults-diff.md"))
      assert_includes markdown, "does not read `README.md`"
    end
  end

  def test_verify_checks_only_manifest_entries
    Dir.mktmpdir do |directory|
      manifest = File.join(directory, "manifest.json")
      File.write(manifest, JSON.generate(
        "version" => 1,
        "domains" => { "com.apple.example" => { "NewScalar" => { "type" => "string", "value" => "live only" } } },
        "host_domains" => {}
      ))

      _stdout, stderr, status = Open3.capture3(
        "/usr/bin/ruby", SCRIPT, "verify",
        "--manifest", manifest,
        "--preferences-dir", File.join(FIXTURES, "preferences")
      )

      refute status.success?
      assert_includes stderr, "com.apple.example"
    end
  end
end
