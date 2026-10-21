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

func TestMiseLockUpdateScopes(t *testing.T) {
	for _, failScope := range []string{"", "project", "global"} {
		name := failScope
		if name == "" {
			name = "success"
		}
		t.Run(name, func(t *testing.T) {
			temp := t.TempDir()
			temp, err := filepath.EvalSymlinks(temp)
			if err != nil {
				t.Fatal(err)
			}
			repo := filepath.Join(temp, "repo")
			bin := filepath.Join(temp, "bin")
			copyTrackedFiles(t, filepath.Join("..", ".."), repo, ".github/scripts/update-mise-locks.sh\x00files/home/.config/mise/config.toml\x00files/home/.config/mise/config.home.toml\x00")
			writePolicyFixture(t, filepath.Join(bin, "mise"), `#!/bin/bash
set -euo pipefail
[[ "$PWD" == "$EXPECTED_REPO" ]]
[[ "$MISE_AUTO_ENV" == false && "$MISE_ENV" == home ]]
[[ "$MISE_CEILING_PATHS" == "$(dirname "$EXPECTED_REPO")" ]]
[[ -d "$MISE_SYSTEM_CONFIG_DIR" && -z "$(ls -A "$MISE_SYSTEM_CONFIG_DIR")" ]]
[[ -z "${MISE_GLOBAL_CONFIG_FILE+x}${MISE_GLOBAL_CONFIG_ROOT+x}${MISE_SYSTEM_CONFIG_FILE+x}" ]]
[[ -z "${MISE_OVERRIDE_CONFIG_FILENAMES+x}${MISE_OVERRIDE_TOOL_VERSIONS_FILENAMES+x}" ]]
if [[ "$*" == 'lock --bump' ]]; then
  scope=project
  [[ -d "$MISE_CONFIG_DIR" && -z "$(ls -A "$MISE_CONFIG_DIR")" ]]
elif [[ "$*" == 'lock --global --bump' ]]; then
  scope=global
  [[ "$MISE_CONFIG_DIR" == "$EXPECTED_REPO/files/home/.config/mise" ]]
  [[ -f "$MISE_CONFIG_DIR/config.toml" && -f "$MISE_CONFIG_DIR/config.home.toml" ]]
else
  echo "Unexpected mise command: $*" >&2
  exit 1
fi
printf '%s\n' "$scope" >> "$COMMAND_LOG"
printf '%s\n' "$MISE_SYSTEM_CONFIG_DIR" > "$SYSTEM_LOG"
if [[ "$FAIL_SCOPE" == "$scope" ]]; then
  echo "$scope lock failed" >&2
  exit 7
fi
echo "$scope lock updated"
`)
			cmd := exec.CommandContext(t.Context(), "bash", filepath.Join(repo, ".github", "scripts", "update-mise-locks.sh"))
			cmd.Dir = temp
			cmd.Env = []string{
				"HOME=" + filepath.Join(temp, "home"), "PATH=" + bin + ":/usr/bin:/bin", "TMPDIR=" + temp,
				"EXPECTED_REPO=" + repo, "COMMAND_LOG=" + filepath.Join(temp, "commands"), "SYSTEM_LOG=" + filepath.Join(temp, "system"), "FAIL_SCOPE=" + failScope,
				"MISE_CONFIG_DIR=/unrelated/global", "MISE_SYSTEM_CONFIG_DIR=/unrelated/system", "MISE_CEILING_PATHS=/unrelated/ancestor", "MISE_AUTO_ENV=true", "MISE_ENV=work,macos",
				"MISE_GLOBAL_CONFIG_FILE=/unrelated/global.toml", "MISE_GLOBAL_CONFIG_ROOT=/unrelated/root", "MISE_SYSTEM_CONFIG_FILE=/unrelated/system.toml",
				"MISE_OVERRIDE_CONFIG_FILENAMES=unrelated.toml", "MISE_OVERRIDE_TOOL_VERSIONS_FILENAMES=unrelated-versions",
			}
			output, err := cmd.CombinedOutput()
			if (err != nil) != (failScope != "") {
				t.Fatalf("updater failure = %v, fail scope %q:\n%s", err, failScope, output)
			}
			want := "project\nglobal\n"
			if failScope == "project" {
				want = "project\n"
			}
			if commands := readPolicyLog(t, filepath.Join(temp, "commands")); commands != want {
				t.Fatalf("lock scope order = %q, want %q:\n%s", commands, want, output)
			}
			if failScope != "" && !strings.Contains(string(output), failScope+" lock failed") {
				t.Fatalf("updater swallowed resolver failure:\n%s", output)
			}
			system := strings.TrimSpace(readPolicyLog(t, filepath.Join(temp, "system")))
			if _, err := os.Stat(system); !os.IsNotExist(err) {
				t.Fatalf("updater did not clean its temporary config directory %s: %v", system, err)
			}
		})
	}
}
