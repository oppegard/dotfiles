package integration

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"
)

type claudeTest struct {
	home, bin, checker, mise string
	env                      []string
}

func newClaudeTest(t *testing.T) claudeTest {
	t.Helper()
	home := t.TempDir()
	bin := filepath.Join(home, "bin")
	config := filepath.Join(home, ".config", "mise")
	for _, dir := range []string{bin, config, filepath.Join(home, ".dotfiles", "bin")} {
		if err := os.MkdirAll(dir, 0o755); err != nil {
			t.Fatal(err)
		}
	}
	bash, err := exec.LookPath("bash")
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(bash, filepath.Join(bin, "bash")); err != nil {
		t.Fatal(err)
	}
	mise, err := exec.LookPath("mise")
	if err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"config.toml", "config.macos.toml"} {
		contents, err := os.ReadFile(filepath.Join("..", "..", "files", "home", ".config", "mise", name))
		if err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(config, name), contents, 0o644); err != nil {
			t.Fatal(err)
		}
	}
	checker := filepath.Join(home, ".dotfiles", "bin", "check-claude")
	contents, err := os.ReadFile(filepath.Join("..", "..", "bin", "check-claude"))
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(checker, contents, 0o755); err != nil {
		t.Fatal(err)
	}
	return claudeTest{home: home, bin: bin, checker: checker, mise: mise, env: []string{
		"HOME=" + home,
		"PATH=" + bin,
		"XDG_CONFIG_HOME=" + filepath.Join(home, ".config"),
		"XDG_DATA_HOME=" + filepath.Join(home, ".local", "share"),
		"XDG_STATE_HOME=" + filepath.Join(home, ".local", "state"),
		"XDG_CACHE_HOME=" + filepath.Join(home, ".cache"),
		"MISE_CONFIG_DIR=" + config,
		"MISE_DATA_DIR=" + filepath.Join(home, "mise-data"),
		"MISE_STATE_DIR=" + filepath.Join(home, "mise-state"),
		"MISE_CACHE_DIR=" + filepath.Join(home, "mise-cache"),
		"MISE_ENV=macos",
		"MISE_TRUSTED_CONFIG_PATHS=" + home,
		"MISE_YES=1",
		"MISE_OFFLINE=1",
		"MISE_COLOR=0",
		"NO_COLOR=1",
		"ANTHROPIC_API_KEY=test-api-key",
		"CLAUDE_CODE_OAUTH_TOKEN=test-oauth-token",
		"CLAUDE_CONFIG_DIR=" + filepath.Join(home, "claude-config"),
		"ANTHROPIC_MODEL=test-model",
	}}
}

func (fixture claudeTest) stub(t *testing.T, path, source string) {
	t.Helper()
	if err := os.WriteFile(path, []byte("#!/usr/bin/env bash\nset -eu\n"+source+"\n"), 0o755); err != nil {
		t.Fatal(err)
	}
}

func (fixture claudeTest) run(t *testing.T, program string, args ...string) (string, error) {
	t.Helper()
	ctx, cancel := context.WithTimeout(t.Context(), 60*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, program, args...)
	cmd.Dir = fixture.home
	cmd.Env = fixture.env
	cmd.Stdin = strings.NewReader("stdin must not reach Claude\n")
	cmd.WaitDelay = time.Second
	output, err := cmd.CombinedOutput()
	if ctx.Err() != nil {
		t.Fatalf("command exceeded test deadline: %v\n%s", ctx.Err(), output)
	}
	return string(output), err
}

func TestClaudeCheckRequest(t *testing.T) {
	fixture := newClaudeTest(t)
	fixture.stub(t, filepath.Join(fixture.bin, "claude"), `
if IFS= read -r line; then
  echo 'Claude received stdin' >&2
  exit 2
fi
printf '%s\0' "$@" > "$HOME/args"
printf '%s\n' "$ANTHROPIC_API_KEY" "$CLAUDE_CODE_OAUTH_TOKEN" "$CLAUDE_CONFIG_DIR" "$ANTHROPIC_MODEL" > "$HOME/auth"
printf 'OK\n'
`)
	output, err := fixture.run(t, fixture.checker)
	if err != nil || output != "Claude is ready.\n" {
		t.Fatalf("readiness check failed: %v\n%s", err, output)
	}
	args, err := os.ReadFile(filepath.Join(fixture.home, "args"))
	if err != nil {
		t.Fatal(err)
	}
	want := []string{"--print", "--safe-mode", "--tools", "", "--strict-mcp-config", "--mcp-config", `{"mcpServers":{}}`,
		"--no-session-persistence", "--effort", "low", "--max-turns", "1", "--output-format", "text",
		"--system-prompt", "Reply with exactly OK.", "Reply with exactly OK."}
	if got := strings.Split(strings.TrimSuffix(string(args), "\x00"), "\x00"); !reflect.DeepEqual(got, want) {
		t.Fatalf("Claude arguments = %q, want %q", got, want)
	}
	auth, err := os.ReadFile(filepath.Join(fixture.home, "auth"))
	if err != nil {
		t.Fatal(err)
	}
	if want := "test-api-key\ntest-oauth-token\n" + filepath.Join(fixture.home, "claude-config") + "\ntest-model\n"; string(auth) != want {
		t.Fatalf("Claude did not inherit the caller's authentication and model environment: %q", auth)
	}
}

func TestClaudeCheckFailures(t *testing.T) {
	for _, test := range []struct {
		name, source string
		args         []string
		want         []string
	}{
		{name: "request failure", source: "echo 'Authentication failed.'; echo 'Token refresh failed.' >&2; exit 7", want: []string{"status 7", "Authentication failed.", "Token refresh failed."}},
		{name: "nonzero OK", source: "echo OK; exit 1", want: []string{"status 1", "OK"}},
		{name: "unexpected reply", source: "echo 'Login required.'; echo 'Request diagnostic.' >&2", want: []string{"expected OK", "Login required.", "Request diagnostic."}},
		{name: "empty reply", source: ":", want: []string{"expected OK"}},
		{name: "missing executable", want: []string{"claude", "status 127"}},
		{name: "unexpected arguments", source: "echo 'Unexpected invocation'", args: []string{"--timeout", "1"}, want: []string{"Usage: check-claude"}},
	} {
		t.Run(test.name, func(t *testing.T) {
			fixture := newClaudeTest(t)
			if test.source != "" {
				fixture.stub(t, filepath.Join(fixture.bin, "claude"), test.source)
			}
			output, err := fixture.run(t, fixture.checker, test.args...)
			if err == nil || strings.Contains(output, "Claude is ready.") || strings.Contains(output, "Unexpected invocation") {
				t.Fatalf("check should fail: %v\n%s", err, output)
			}
			for _, want := range test.want {
				if !strings.Contains(output, want) {
					t.Errorf("failure lacks %q:\n%s", want, output)
				}
			}
		})
	}
}

func TestClaudeDaily(t *testing.T) {
	for _, test := range []struct {
		name, reply, audio, order string
		fails                     bool
	}{
		{name: "success", reply: "echo OK", audio: ":", order: "claude\naudio\n"},
		{name: "Claude failure", reply: "echo 'Login required.'; exit 1", audio: ":", order: "claude\n", fails: true},
		{name: "audio failure", reply: "echo OK", audio: "exit 3", order: "claude\naudio\n", fails: true},
	} {
		t.Run(test.name, func(t *testing.T) {
			fixture := newClaudeTest(t)
			fixture.stub(t, filepath.Join(fixture.bin, "claude"), "echo claude >> \"$HOME/order\"\n"+test.reply)
			fixture.stub(t, filepath.Join(fixture.home, ".dotfiles", "bin", "check-meet-system-audio.command"), "echo audio >> \"$HOME/order\"\n"+test.audio)
			output, err := fixture.run(t, fixture.mise, "run", "--skip-tools", "daily")
			if (err != nil) != test.fails {
				t.Fatalf("daily failure = %v, want %v:\n%s", err, test.fails, output)
			}
			order, err := os.ReadFile(filepath.Join(fixture.home, "order"))
			if err != nil || string(order) != test.order {
				t.Fatalf("daily order = %q, %v; want %q:\n%s", order, err, test.order, output)
			}
		})
	}
}

func TestClaudeCheckTimeout(t *testing.T) {
	fixture := newClaudeTest(t)
	sleep, err := exec.LookPath("sleep")
	if err != nil {
		t.Fatal(err)
	}
	fixture.stub(t, filepath.Join(fixture.bin, "claude"), "trap 'echo terminated > \"$HOME/terminated\"; exit 0' TERM\necho 'Waiting for Claude response.' >&2\nwhile :; do \""+sleep+"\" 1; done")
	start := time.Now()
	output, err := fixture.run(t, fixture.mise, "run", "--skip-tools", "--timeout", "1s", "claude:check")
	elapsed := time.Since(start)
	if err == nil || !strings.Contains(strings.ToLower(output), "timed out") || !strings.Contains(output, "Waiting for Claude response.") {
		t.Fatalf("mise should report the Claude timeout: %v\n%s", err, output)
	}
	if elapsed < time.Second || elapsed >= 10*time.Second {
		t.Fatalf("1-second task timeout finished after %s:\n%s", elapsed, output)
	}
	if _, err := os.Stat(filepath.Join(fixture.home, "terminated")); err != nil {
		t.Fatalf("Claude did not receive TERM: %v\n%s", err, output)
	}
}
