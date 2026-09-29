package integration

import (
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

func TestDotfBootstrapTwice(t *testing.T) {
	if os.Getenv("DOTFILES_INTEGRATION_DISPOSABLE") != "1" {
		if os.Getenv("GITHUB_ACTIONS") == "true" {
			t.Fatal("CI must declare its disposable runner before running the bootstrap test")
		}
		t.Skip("bootstrap changes packages and machine settings; run in a disposable VM with DOTFILES_INTEGRATION_DISPOSABLE=1")
	}
	git, err := exec.LookPath("git")
	if err != nil {
		t.Fatal(err)
	}
	sourceCommand := exec.CommandContext(t.Context(), git, "rev-parse", "--show-toplevel")
	source, err := sourceCommand.Output()
	if err != nil {
		t.Fatal(err)
	}
	sourceRoot := strings.TrimSpace(string(source))
	filesCommand := exec.CommandContext(t.Context(), git, "ls-files", "-z")
	filesCommand.Dir = sourceRoot
	files, err := filesCommand.Output()
	if err != nil {
		t.Fatal(err)
	}

	temp := t.TempDir()
	repo := filepath.Join(temp, "repo")
	copyTrackedFiles(t, sourceRoot, repo, string(files))
	home := filepath.Join(temp, "home")
	if err := os.MkdirAll(home, 0o755); err != nil {
		t.Fatal(err)
	}
	if runtime.GOOS == "darwin" {
		bin := filepath.Join(home, ".local", "bin")
		if err := os.MkdirAll(bin, 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.Symlink("/usr/bin/true", filepath.Join(bin, "chsh")); err != nil {
			t.Fatal(err)
		}
	}

	env := make(map[string]string)
	for _, entry := range os.Environ() {
		key, value, ok := strings.Cut(entry, "=")
		if !ok || strings.HasPrefix(key, "MISE_") || strings.HasPrefix(key, "GIT_CONFIG_") || key == "GIT_DIR" || key == "GIT_WORK_TREE" {
			continue
		}
		env[key] = value
	}
	for key, value := range map[string]string{
		"HOME":                home,
		"XDG_CONFIG_HOME":     filepath.Join(home, ".config"),
		"XDG_CACHE_HOME":      filepath.Join(home, ".cache"),
		"XDG_DATA_HOME":       filepath.Join(home, ".local", "share"),
		"XDG_STATE_HOME":      filepath.Join(home, ".local", "state"),
		"MISE_AUTO_ENV":       "true",
		"MISE_ENV":            "home",
		"MISE_YES":            "true",
		"MISE_VERBOSE":        "0",
		"CI":                  "true",
		"NONINTERACTIVE":      "true",
		"DEBUG":               "true",
		"GIT_TERMINAL_PROMPT": "0",
		"GIT_CONFIG_NOSYSTEM": "1",
		"GIT_CONFIG_GLOBAL":   "/dev/null",
	} {
		env[key] = value
	}
	for _, key := range []string{"MISE_DATA_DIR", "MISE_CACHE_DIR"} {
		if value, ok := os.LookupEnv(key); ok {
			env[key] = value
		}
	}
	if runtime.GOOS == "darwin" {
		env["MISE_SYSTEM_PACKAGES_MANAGERS"] = "brew"
	}
	commandEnv := make([]string, 0, len(env))
	for key, value := range env {
		commandEnv = append(commandEnv, key+"="+value)
	}
	runGit := func(args ...string) {
		t.Helper()
		cmd := exec.CommandContext(t.Context(), git, args...)
		cmd.Dir = repo
		cmd.Env = commandEnv
		if output, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("git %v failed: %v\n%s", args, err, output)
		}
	}
	runGit("init", "--initial-branch=main")
	runGit("add", ".")
	runGit("-c", "user.name=Integration Test", "-c", "user.email=integration@example.invalid", "-c", "commit.gpgsign=false", "commit", "-m", "test: establish bootstrap fixture")
	for run := 1; run <= 2; run++ {
		cmd := exec.CommandContext(t.Context(), filepath.Join(repo, "bin", "dotf"), "run")
		cmd.Dir = repo
		cmd.Env = commandEnv
		output, err := cmd.CombinedOutput()
		if err != nil {
			t.Fatalf("dotf run %d failed: %v\n%s", run, err, output)
		}
		if !strings.Contains(string(output), "Tool prerequisites installed") {
			t.Fatalf("dotf run %d lacked completion evidence:\n%s", run, output)
		}
		link, err := os.Readlink(filepath.Join(home, ".dotfiles"))
		if err != nil || link != repo {
			t.Fatalf("dotf run %d left dotfiles link %q, %v; want %q", run, link, err, repo)
		}
		if _, err := os.Lstat(filepath.Join(home, ".config", "mise", "config.toml")); err != nil {
			t.Fatalf("dotf run %d did not apply mise config: %v", run, err)
		}
		t.Logf("dotf run %d completed", run)
	}
	logs, err := filepath.Glob(filepath.Join(repo, "logs", "dotf_*.log"))
	if err != nil || len(logs) == 0 {
		t.Fatalf("bootstrap logs = %d, %v; want a run log", len(logs), err)
	}
}
