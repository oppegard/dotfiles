package integration

import (
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

const betterDisplayStub = `#!/bin/bash
set -eu
case "${0##*/}" in
pgrep)
  status=$(head -n 1 "$BETTERDISPLAY_TEST_DIR/statuses")
  tail -n +2 "$BETTERDISPLAY_TEST_DIR/statuses" > "$BETTERDISPLAY_TEST_DIR/remaining"
  if [ -s "$BETTERDISPLAY_TEST_DIR/remaining" ]; then
    mv "$BETTERDISPLAY_TEST_DIR/remaining" "$BETTERDISPLAY_TEST_DIR/statuses"
  fi
  printf 'pgrep=%s\n' "$status" >> "$BETTERDISPLAY_TEST_DIR/commands"
  if [ "$status" -gt 1 ]; then echo 'simulated process inspection failure' >&2; fi
  exit "$status"
  ;;
defaults)
  case "$1" in
  export) : > "$3" ;;
  import) echo import >> "$BETTERDISPLAY_TEST_DIR/commands" ;;
  *) exit 64 ;;
  esac
  ;;
plutil)
  if [ "$1" = -extract ]; then printf '<true/>\n' > "$5"; fi
  ;;
osascript) echo quit >> "$BETTERDISPLAY_TEST_DIR/commands" ;;
open) echo open >> "$BETTERDISPLAY_TEST_DIR/commands" ;;
sleep) ;;
*) exit 64 ;;
esac
`

func TestBetterDisplayImportLifecycle(t *testing.T) {
	for _, tc := range []struct {
		name, statuses, wantOutput, wantLog string
		wantExit                            int
		wantQuit, wantImport                bool
	}{
		{
			name: "inspection error before quit", statuses: "3", wantExit: 3,
			wantOutput: "Cannot inspect BetterDisplay",
		},
		{
			name: "inspection error during shutdown", statuses: "0\n3", wantExit: 3,
			wantQuit: true, wantOutput: "Cannot inspect BetterDisplay",
		},
		{
			name: "inspection error during startup", statuses: "1\n3", wantExit: 3,
			wantImport: true, wantOutput: "Cannot inspect BetterDisplay",
		},
		{
			name: "wait for shutdown and startup", statuses: "0\n0\n1\n1\n0",
			wantQuit: true, wantImport: true, wantOutput: "Imported BetterDisplay",
			wantLog: "pgrep=0\nquit\npgrep=0\npgrep=1\nimport\nopen\npgrep=1\npgrep=0\n",
		},
		{
			name: "already stopped", statuses: "1\n0", wantImport: true,
			wantOutput: "Imported BetterDisplay",
			wantLog:    "pgrep=1\nimport\nopen\npgrep=0\n",
		},
		{
			name: "shutdown timeout", statuses: "0", wantExit: 1, wantQuit: true,
			wantOutput: "did not quit within 5 seconds",
		},
		{
			name: "startup timeout", statuses: "1", wantExit: 1, wantImport: true,
			wantOutput: "did not start within 5 seconds",
		},
	} {
		t.Run(tc.name, func(t *testing.T) {
			temp := t.TempDir()
			bin := filepath.Join(temp, "stubs")
			repo := filepath.Join(temp, "repo")
			for _, dir := range []string{bin, filepath.Join(temp, "app")} {
				if err := os.MkdirAll(dir, 0o755); err != nil {
					t.Fatal(err)
				}
			}
			copyTrackedFiles(t, filepath.Join("..", ".."), repo, "bin/betterdisplay-prefs\x00files/macos/BetterDisplay.plist\x00")
			script := filepath.Join(repo, "bin", "betterdisplay-prefs")
			contents, err := os.ReadFile(script)
			if err != nil {
				t.Fatal(err)
			}
			writePolicyFixture(t, script, strings.Replace(string(contents),
				`APPLICATION_PATH="/Applications/BetterDisplay.app"`,
				`APPLICATION_PATH="$BETTERDISPLAY_TEST_DIR/app"`, 1))
			for _, name := range []string{"pgrep", "defaults", "plutil", "osascript", "open", "sleep"} {
				writePolicyFixture(t, filepath.Join(bin, name), betterDisplayStub)
			}
			writePolicyFixture(t, filepath.Join(temp, "statuses"), tc.statuses+"\n")
			cmd := exec.CommandContext(t.Context(), "bash", script, "import")
			cmd.Env = []string{"PATH=" + bin + ":/usr/bin:/bin", "TMPDIR=" + temp, "BETTERDISPLAY_TEST_DIR=" + temp}
			output, err := cmd.CombinedOutput()
			exitCode := 0
			if err != nil {
				var exitError *exec.ExitError
				if !errors.As(err, &exitError) {
					t.Fatal(err)
				}
				exitCode = exitError.ExitCode()
			}
			if exitCode != tc.wantExit || !strings.Contains(string(output), tc.wantOutput) {
				t.Errorf("exit = %d, want %d with %q:\n%s", exitCode, tc.wantExit, tc.wantOutput, output)
			}
			if tc.wantExit != 0 && strings.Contains(string(output), "Imported BetterDisplay") {
				t.Errorf("failed import reported success:\n%s", output)
			}
			log := readPolicyLog(t, filepath.Join(temp, "commands"))
			for command, want := range map[string]bool{"quit": tc.wantQuit, "import": tc.wantImport, "open": tc.wantImport} {
				if got := strings.Contains("\n"+log, "\n"+command+"\n"); got != want {
					t.Errorf("%s called = %v, want %v:\n%s", command, got, want, log)
				}
			}
			if tc.wantLog != "" && log != tc.wantLog {
				t.Errorf("unexpected lifecycle order:\n%s\nwant:\n%s", log, tc.wantLog)
			}
		})
	}
}
