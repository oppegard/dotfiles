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
	mise, err := exec.LookPath("mise")
	if err != nil {
		t.Fatal(err)
	}
	mise, err = filepath.EvalSymlinks(mise)
	if err != nil {
		t.Fatal(err)
	}
	sourceCommand := exec.CommandContext(t.Context(), git, "rev-parse", "--show-toplevel")
	source, err := sourceCommand.Output()
	if err != nil {
		t.Fatal(err)
	}
	repo := strings.TrimSpace(string(source))
	home, err := os.UserHomeDir()
	if err != nil {
		t.Fatal(err)
	}
	linkPath := filepath.Join(home, ".dotfiles")
	if link, err := os.Readlink(linkPath); err == nil && link != repo {
		t.Fatalf("%s points to %q, not the checkout %q", linkPath, link, repo)
	} else if err != nil && !os.IsNotExist(err) {
		t.Fatalf("cannot inspect %s: %v", linkPath, err)
	}
	chshPath := filepath.Join(home, ".local", "bin", "chsh")
	if runtime.GOOS == "darwin" {
		if link, err := os.Readlink(chshPath); err == nil && link != "/usr/bin/true" {
			t.Fatalf("%s points to %q, not /usr/bin/true", chshPath, link)
		} else if err != nil && !os.IsNotExist(err) {
			t.Fatalf("cannot inspect %s: %v", chshPath, err)
		}
	}
	for _, name := range []string{".bash_profile", ".bashrc", ".gitconfig"} {
		if err := os.Remove(filepath.Join(home, name)); err != nil && !os.IsNotExist(err) {
			t.Fatal(err)
		}
	}
	if runtime.GOOS == "darwin" {
		bin := filepath.Join(home, ".local", "bin")
		if err := os.MkdirAll(bin, 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.Symlink("/usr/bin/true", chshPath); err != nil && !os.IsExist(err) {
			t.Fatal(err)
		}
	}

	env := make(map[string]string)
	for _, entry := range os.Environ() {
		key, value, ok := strings.Cut(entry, "=")
		if ok && key != "MISE_SYSTEM_PACKAGES_MANAGERS" {
			env[key] = value
		}
	}
	for key, value := range map[string]string{
		"MISE_AUTO_ENV":  "true",
		"MISE_BIN":       mise,
		"MISE_ENV":       "home",
		"MISE_YES":       "true",
		"MISE_VERBOSE":   "0",
		"CI":             "true",
		"NONINTERACTIVE": "true",
		"DEBUG":          "true",
	} {
		env[key] = value
	}
	if runtime.GOOS == "darwin" {
		env["MISE_SYSTEM_PACKAGES_MANAGERS"] = "brew"
	}
	commandEnv := make([]string, 0, len(env))
	for key, value := range env {
		commandEnv = append(commandEnv, key+"="+value)
	}
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
		link, err := os.Readlink(linkPath)
		if err != nil || link != repo {
			t.Fatalf("dotf run %d left dotfiles link %q, %v; want %q", run, link, err, repo)
		}
		if _, err := os.Lstat(filepath.Join(home, ".config", "mise", "config.toml")); err != nil {
			t.Fatalf("dotf run %d did not apply mise config: %v", run, err)
		}
		t.Logf("dotf run %d completed", run)
	}
}
