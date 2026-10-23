package integration

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func writePolicyFixture(t *testing.T, path, contents string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(contents), 0o755); err != nil {
		t.Fatal(err)
	}
}

func readPolicyLog(t *testing.T, path string) string {
	t.Helper()
	contents, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	return string(contents)
}

func TestSetupUsesCommittedToolLocks(t *testing.T) {
	for _, platform := range []string{"Linux", "Darwin"} {
		t.Run(platform, func(t *testing.T) {
			temp := t.TempDir()
			temp, err := filepath.EvalSymlinks(temp)
			if err != nil {
				t.Fatal(err)
			}
			repo := filepath.Join(temp, "repo")
			home := filepath.Join(temp, "home")
			bin := filepath.Join(home, ".local", "bin")
			copyTrackedFiles(t, filepath.Join("..", ".."), repo, "bin/setup.sh\x00bin/lib/dotf-common.sh\x00")
			writePolicyFixture(t, filepath.Join(bin, "mise"), `#!/bin/bash
set -eu
if [[ "$1" == activate ]]; then exit 0; fi
shift 2
printf 'mise %s\n' "$*" >> "$HOME/commands"
`)
			for _, name := range []string{"git", "brew", "open"} {
				writePolicyFixture(t, filepath.Join(bin, name), "#!/bin/bash\nprintf '%s %s\\n' '"+name+"' \"$*\" >> \"$HOME/commands\"\n")
			}
			writePolicyFixture(t, filepath.Join(bin, "uname"), "#!/bin/bash\nprintf '%s\\n' '"+platform+"'\n")
			cmd := exec.CommandContext(t.Context(), "bash", filepath.Join(repo, "bin", "setup.sh"))
			cmd.Env = []string{"HOME=" + home, "PATH=" + bin + ":/usr/bin:/bin", "MISE_ENV=home"}
			output, err := cmd.CombinedOutput()
			if err != nil {
				t.Fatalf("setup failed with stubs: %v\n%s", err, output)
			}
			commands := readPolicyLog(t, filepath.Join(home, "commands"))
			for _, want := range []string{"mise install --locked gum\n", "mise bootstrap --locked\n", "mise bootstrap packages upgrade --yes\n", "mise prune --tools --yes\n"} {
				if !strings.Contains(commands, want) {
					t.Errorf("setup lacks %q:\n%s", want, commands)
				}
			}
			for _, forbidden := range []string{"mise upgrade", "mise install gum\n", "mise bootstrap\n", "MISE UPGRADE"} {
				if strings.Contains(commands, forbidden) {
					t.Errorf("setup must not request %q:\n%s", forbidden, commands)
				}
			}
			if platform == "Darwin" {
				for _, want := range []string{"brew bundle install --file=" + repo + "/Brewfile\n", "brew cleanup\n"} {
					if !strings.Contains(commands, want) {
						t.Errorf("setup lacks package maintenance %q:\n%s", want, commands)
					}
				}
			}
		})
	}
}

const miseLockUpdateFiles = ".github/scripts/update-mise-locks.sh\x00.github/scripts/mise_lock_plan.rb\x00mise.toml\x00files/home/.config/mise/config.toml\x00files/home/.config/mise/config.home.toml\x00"

const miseLockStubPrefix = `#!/bin/bash
set -euo pipefail
[[ "$PWD" == "$EXPECTED_REPO" ]]
[[ "$MISE_SAFE" == 1 ]]
[[ "$MISE_AUTO_ENV" == false && "$MISE_ENV" == home ]]
[[ "$MISE_CEILING_PATHS" == "$(dirname "$EXPECTED_REPO")" ]]
[[ -d "$MISE_SYSTEM_CONFIG_DIR" && -z "$(ls -A "$MISE_SYSTEM_CONFIG_DIR")" ]]
[[ -z "${MISE_GLOBAL_CONFIG_FILE+x}${MISE_CONFIG_FILE+x}${MISE_GLOBAL_CONFIG_ROOT+x}${MISE_SYSTEM_CONFIG_FILE+x}" ]]
[[ -z "${MISE_OVERRIDE_CONFIG_FILENAMES+x}${MISE_OVERRIDE_TOOL_VERSIONS_FILENAMES+x}" ]]
if [[ "$1 $2 $3" == "config get settings.minimum_release_age" ]]; then
  file=""
  prev=""
  for arg in "$@"; do
    if [[ "$prev" == --file ]]; then
      file=$arg
    fi
    prev=$arg
  done
  grep -F -q -- 'minimum_release_age = "7d"' "$file"
  printf '%s\n' 7d
  exit 0
fi
[[ "$MISE_MINIMUM_RELEASE_AGE" == 7d ]]
scope=project
if [[ "$1 $2" == "lock --global" ]]; then
  scope=global
  [[ "$MISE_CONFIG_DIR" == "$EXPECTED_REPO/files/home/.config/mise" ]]
  [[ -f "$MISE_CONFIG_DIR/config.toml" && -f "$MISE_CONFIG_DIR/config.home.toml" ]]
else
  [[ -d "$MISE_CONFIG_DIR" && -z "$(ls -A "$MISE_CONFIG_DIR")" ]]
fi
printf '%s %s\n' "$scope" "$*" >> "$COMMAND_LOG"
printf '%s\n' "$MISE_SYSTEM_CONFIG_DIR" > "$SYSTEM_LOG"
`

func prepareLockUpdate(t *testing.T, stub string) (string, string, string) {
	t.Helper()
	temp := t.TempDir()
	temp, err := filepath.EvalSymlinks(temp)
	if err != nil {
		t.Fatal(err)
	}
	repo := filepath.Join(temp, "repo")
	bin := filepath.Join(temp, "bin")
	copyTrackedFiles(t, filepath.Join("..", ".."), repo, miseLockUpdateFiles)
	writePolicyFixture(t, filepath.Join(bin, "mise"), stub)
	return temp, repo, bin
}

func lockUpdateCommand(t *testing.T, temp, repo, bin string, extra ...string) *exec.Cmd {
	t.Helper()
	cmd := exec.CommandContext(t.Context(), "bash", filepath.Join(repo, ".github", "scripts", "update-mise-locks.sh"))
	cmd.Dir = temp
	cmd.Env = append([]string{
		"HOME=" + filepath.Join(temp, "home"),
		"PATH=" + bin + ":/usr/bin:/bin",
		"TMPDIR=" + temp,
		"EXPECTED_REPO=" + repo,
		"COMMAND_LOG=" + filepath.Join(temp, "commands"),
		"SYSTEM_LOG=" + filepath.Join(temp, "system"),
		"MISE_SAFE=0",
		"MISE_CONFIG_DIR=/unrelated/global",
		"MISE_SYSTEM_CONFIG_DIR=/unrelated/system",
		"MISE_CEILING_PATHS=/unrelated/ancestor",
		"MISE_AUTO_ENV=true",
		"MISE_ENV=work,macos",
		"MISE_GLOBAL_CONFIG_FILE=/unrelated/global.toml",
		"MISE_CONFIG_FILE=/unrelated/config.toml",
		"MISE_GLOBAL_CONFIG_ROOT=/unrelated/root",
		"MISE_SYSTEM_CONFIG_FILE=/unrelated/system.toml",
		"MISE_OVERRIDE_CONFIG_FILENAMES=unrelated.toml",
		"MISE_OVERRIDE_TOOL_VERSIONS_FILENAMES=unrelated-versions",
		"MISE_MINIMUM_RELEASE_AGE=1h",
	}, extra...)
	return cmd
}

func assertLockTempCleaned(t *testing.T, temp string) {
	t.Helper()
	system := strings.TrimSpace(readPolicyLog(t, filepath.Join(temp, "system")))
	if _, err := os.Stat(system); !os.IsNotExist(err) {
		t.Fatalf("updater did not clean its temporary config directory %s: %v", system, err)
	}
}

func TestMiseLockUpdateScopes(t *testing.T) {
	stub := miseLockStubPrefix + `
case "$*" in
  "lock --bump --dry-run --json"|"lock --bump --dry-run --json --minimum-release-age 0s"|"lock --global --bump --dry-run --json"|"lock --global --bump --dry-run --json --minimum-release-age 0s")
    ;;
  *)
    echo "Unexpected mise command: $*" >&2
    exit 1
    ;;
esac
if [[ "$FAIL_SCOPE" == "$scope" ]]; then
  echo "$scope lock failed" >&2
  exit 7
fi
printf '%s\n' '[]'
`
	projectAged := "project lock --bump --dry-run --json\n"
	projectFresh := "project lock --bump --dry-run --json --minimum-release-age 0s\n"
	globalAged := "global lock --global --bump --dry-run --json\n"
	globalFresh := "global lock --global --bump --dry-run --json --minimum-release-age 0s\n"
	for _, failScope := range []string{"", "project", "global"} {
		name := failScope
		if name == "" {
			name = "success"
		}
		t.Run(name, func(t *testing.T) {
			temp, repo, bin := prepareLockUpdate(t, stub)
			cmd := lockUpdateCommand(t, temp, repo, bin, "FAIL_SCOPE="+failScope)
			output, err := cmd.CombinedOutput()
			if (err != nil) != (failScope != "") {
				t.Fatalf("updater failure = %v, fail scope %q:\n%s", err, failScope, output)
			}
			want := projectAged + projectFresh + globalAged + globalFresh
			if failScope == "project" {
				want = projectAged
			}
			if failScope == "global" {
				want = projectAged + projectFresh + globalAged
			}
			if commands := readPolicyLog(t, filepath.Join(temp, "commands")); commands != want {
				t.Fatalf("lock scope order = %q, want %q:\n%s", commands, want, output)
			}
			if failScope != "" && !strings.Contains(string(output), failScope+" lock failed") {
				t.Fatalf("updater swallowed resolver failure:\n%s", output)
			}
			if failScope == "" && !strings.Contains(string(output), "chore(mise): update tool locks\n") {
				t.Fatalf("updater omitted the empty title:\n%s", output)
			}
			assertLockTempCleaned(t, temp)
		})
	}
}

func TestMiseLockUpdatePlan(t *testing.T) {
	stub := miseLockStubPrefix + `
if [[ "$*" != *--dry-run* ]]; then
  exit 0
fi
if [[ "$*" == *"--minimum-release-age 0s"* ]]; then
  cat "$FIXTURE_DIR/$scope-0s.json"
else
  cat "$FIXTURE_DIR/$scope-7d.json"
fi
`
	fixtures := map[string]string{
		"project-7d.json": `[
  {"name":"rumdl","backend":"github:rvben/rumdl","old_versions":["0.3.0"],"new_versions":["0.2.79"]},
  {"name":"go","backend":"core:go","old_versions":["1.27.1"],"new_versions":[]},
  {"name":"ref","backend":"core:ref","old_versions":["main"],"new_versions":["next"]},
  {"name":"bun","backend":"core:bun","old_versions":["1.4.3"],"new_versions":["1.4.4"]},
  {"name":"ruby","backend":"core:ruby","old_versions":["3.4.1"],"new_versions":["4.0.0"]}
]`,
		"project-0s.json": `[
  {"name":"bun","backend":"core:bun","old_versions":["1.4.3"],"new_versions":["1.4.5"]},
  {"name":"hk","backend":"github:jdx/hk","old_versions":["2.7.0"],"new_versions":["2.8.1"]},
  {"name":"ruby","backend":"core:ruby","old_versions":["3.4.1"],"new_versions":["4.0.0"]}
]`,
		"global-7d.json": `[
  {"name":"node","backend":"core:node","old_versions":["24.22.1"],"new_versions":["24.22.0"]}
]`,
		"global-0s.json": `[
  {"name":"jactionlint","backend":"github:rhysd/actionlint","old_versions":["2.2.0"],"new_versions":["2.3.0"]}
]`,
	}
	for _, emergency := range []string{"", "hk"} {
		name := "adopt"
		if emergency != "" {
			name = "emergency"
		}
		t.Run(name, func(t *testing.T) {
			temp, repo, bin := prepareLockUpdate(t, stub)
			for file, contents := range fixtures {
				writePolicyFixture(t, filepath.Join(temp, file), contents)
			}
			title := filepath.Join(temp, "title.txt")
			body := filepath.Join(temp, "body.md")
			extra := []string{
				"FIXTURE_DIR=" + temp,
				"MISE_LOCK_PR_TITLE_FILE=" + title,
				"MISE_LOCK_PR_BODY_FILE=" + body,
			}
			if emergency != "" {
				extra = append(extra, "MISE_LOCK_EMERGENCY_TOOL="+emergency)
			}
			cmd := lockUpdateCommand(t, temp, repo, bin, extra...)
			output, err := cmd.CombinedOutput()
			if err != nil {
				t.Fatalf("updater failed: %v\n%s", err, output)
			}
			want := "" +
				"project lock --bump --dry-run --json\n" +
				"project lock --bump --dry-run --json --minimum-release-age 0s\n" +
				"global lock --global --bump --dry-run --json\n" +
				"global lock --global --bump --dry-run --json --minimum-release-age 0s\n" +
				"project lock --bump --json bun\n" +
				"project lock --bump --json ruby\n"
			if emergency == "hk" {
				want += "project lock --bump --json --minimum-release-age 0s hk\n"
			}
			if commands := readPolicyLog(t, filepath.Join(temp, "commands")); commands != want {
				t.Fatalf("lock commands = %q, want %q:\n%s", commands, want, output)
			}
			titleText := readPolicyLog(t, title)
			bodyText := readPolicyLog(t, body)
			if emergency == "hk" {
				if titleText != "chore(mise): update bun 1.4.4, ruby 4.0.0 (+1)\n" {
					t.Fatalf("title = %q", titleText)
				}
				if !strings.Contains(bodyText, "Emergency bump for `hk` uses `--minimum-release-age 0s`.") {
					t.Fatalf("body omitted the emergency line:\n%s", bodyText)
				}
				if !strings.Contains(bodyText, "| [hk](https://github.com/jdx/hk) | tools | minor | `2.7.0` → `2.8.1` |  |") {
					t.Fatalf("body omitted the emergency hk row:\n%s", bodyText)
				}
			} else if titleText != "chore(mise): update bun 1.4.4, ruby 4.0.0\n" {
				t.Fatalf("title = %q", titleText)
			}
			for _, want := range []string{
				"| Package | Type | Update | Change | Pending |",
				"|---|---|---|---|---|",
				"| bun | tools | patch | `1.4.3` → `1.4.4` | `1.4.5` |",
				"| ruby | tools | major | `3.4.1` → `4.0.0` |  |",
				"| [jactionlint](https://github.com/rhysd/actionlint) | tools | minor | `2.2.0` | `2.3.0` |",
				"Mise does not refuse a major bump of a `latest` or `lts` request.",
				"This job does not add a major filter.",
				"The updater does not roll a locked version backward when that version is still inside the age window.",
				"MISE_SAFE=1 hides an idiomatic Go pin, so this job does not bump it.",
				"The age window is `7d` from `minimum_release_age`.",
				"https://github.com/jdx/hk/releases",
				"https://github.com/rhysd/actionlint/releases",
			} {
				if !strings.Contains(bodyText, want) {
					t.Fatalf("body omitted %q:\n%s", want, bodyText)
				}
			}
			for _, absent := range []string{"| rumdl |", "| go |", "| node |", "| ref |", "| Scope |"} {
				if strings.Contains(bodyText, absent) {
					t.Fatalf("body kept %q:\n%s", absent, bodyText)
				}
			}
			assertLockTempCleaned(t, temp)
		})
	}

	t.Run("dry-run", func(t *testing.T) {
		temp, repo, bin := prepareLockUpdate(t, stub)
		for file, contents := range fixtures {
			writePolicyFixture(t, filepath.Join(temp, file), contents)
		}
		cmd := lockUpdateCommand(t, temp, repo, bin, "FIXTURE_DIR="+temp, "MISE_LOCK_DRY_RUN=1")
		output, err := cmd.CombinedOutput()
		if err != nil {
			t.Fatalf("dry run failed: %v\n%s", err, output)
		}
		for _, line := range strings.Split(readPolicyLog(t, filepath.Join(temp, "commands")), "\n") {
			if line != "" && !strings.Contains(line, "--dry-run") {
				t.Fatalf("dry run wrote a lock: %q\n%s", line, output)
			}
		}
		if !strings.Contains(string(output), "| ruby | tools | major |") {
			t.Fatalf("dry run omitted the pending report:\n%s", output)
		}
		assertLockTempCleaned(t, temp)
	})

	t.Run("missing-emergency", func(t *testing.T) {
		temp, repo, bin := prepareLockUpdate(t, stub)
		for file, contents := range fixtures {
			writePolicyFixture(t, filepath.Join(temp, file), contents)
		}
		cmd := lockUpdateCommand(t, temp, repo, bin, "FIXTURE_DIR="+temp, "MISE_LOCK_EMERGENCY_TOOL=not-a-tool")
		output, err := cmd.CombinedOutput()
		if err == nil {
			t.Fatalf("updater adopted a missing emergency tool:\n%s", output)
		}
		if !strings.Contains(string(output), "updater did not adopt emergency tool not-a-tool") {
			t.Fatalf("updater failure was not the missing tool:\n%s", output)
		}
		for _, line := range strings.Split(readPolicyLog(t, filepath.Join(temp, "commands")), "\n") {
			if line != "" && !strings.Contains(line, "--dry-run") {
				t.Fatalf("missed emergency tool still wrote a lock: %q\n%s", line, output)
			}
		}
		assertLockTempCleaned(t, temp)
	})
}

func TestMiseLockUpdateRejectsEmergencyName(t *testing.T) {
	temp, repo, bin := prepareLockUpdate(t, miseLockStubPrefix+"exit 1\n")
	cmd := lockUpdateCommand(t, temp, repo, bin, "MISE_LOCK_EMERGENCY_TOOL=hk;touch")
	output, err := cmd.CombinedOutput()
	if err == nil {
		t.Fatalf("updater accepted an emergency tool name:\n%s", output)
	}
	if !strings.Contains(string(output), "updater refused emergency tool name") {
		t.Fatalf("updater failure was not the name check:\n%s", output)
	}
	if _, err := os.Stat(filepath.Join(temp, "commands")); !os.IsNotExist(err) {
		t.Fatalf("rejected emergency tool still invoked mise: %v", err)
	}
}
