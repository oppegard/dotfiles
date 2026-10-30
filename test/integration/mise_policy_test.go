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
if [[ "$1" == -C ]]; then
  shift 2
  printf 'mise -C %s\n' "$*" >> "$HOME/commands"
else
  printf 'mise %s\n' "$*" >> "$HOME/commands"
fi
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
			for _, want := range []string{
				"mise install --locked gum\n",
				"mise -C bootstrap --locked --skip tools --prune-dotfiles\n",
				"mise bootstrap --only tools --locked\n",
				"mise -C bootstrap packages upgrade --yes\n",
				"mise -C prune --tools --yes\n",
			} {
				if !strings.Contains(commands, want) {
					t.Errorf("setup lacks %q:\n%s", want, commands)
				}
			}
			for _, forbidden := range []string{
				"mise upgrade",
				"mise install gum\n",
				"mise -C install --locked gum\n",
				"mise bootstrap\n",
				"mise -C bootstrap --locked --prune-dotfiles\n",
				"MISE UPGRADE",
			} {
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
