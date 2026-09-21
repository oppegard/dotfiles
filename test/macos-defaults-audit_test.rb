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
      assert_equal "mise_current_host_candidate", classifications.fetch("HostOnly")
      assert_equal "mise_candidate", classifications.fetch("Complex")
      assert_equal "unsupported_complex_value", classifications.fetch("Unsupported")

      candidates = File.read(File.join(directory, "mise-candidates.toml"))
      assert_includes candidates, "NewScalar"
      assert_includes candidates, "HostOnly"
      assert_includes candidates, "Complex"
      assert_includes candidates, '"HIDKeyboardModifierMappingDst" = 2'
      assert_includes candidates, 'host = "current"'
      refute_includes candidates, "Unsupported"

      markdown = File.read(File.join(directory, "defaults-diff.md"))
      assert_includes markdown, "does not read `README.md`"
    end
  end

  def test_snapshot_includes_hidden_global_preferences_by_host
    Dir.mktmpdir do |directory|
      snapshot = File.join(directory, "snapshot.json")
      stdout, stderr, status = Open3.capture3(
        "/usr/bin/ruby", SCRIPT, "snapshot",
        "--output", snapshot,
        "--preferences-dir", File.join(FIXTURES, "preferences")
      )

      assert status.success?, "#{stdout}\n#{stderr}"
      data = JSON.parse(File.read(snapshot))
      mapping = data.dig(
        "host_domains", "NSGlobalDomain",
        "com.apple.keyboard.modifiermapping.0-0-0"
      )

      refute_nil mapping
      assert_equal "array", mapping.fetch("type")
      assert_equal 2, mapping.dig("value", 0, "value", "HIDKeyboardModifierMappingDst", "value")
      assert_equal 0, mapping.dig("value", 0, "value", "HIDKeyboardModifierMappingSrc", "value")
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
