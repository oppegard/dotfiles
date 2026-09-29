package integration

import (
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestPreCommitRejectsSecret(t *testing.T) {
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
	temp := t.TempDir()
	repo := filepath.Join(temp, "repo")
	env := []string{
		"PATH=" + filepath.Dir(mise) + ":/usr/bin:/bin:/usr/sbin:/sbin",
		"HOME=" + filepath.Join(temp, "home"),
		"XDG_CONFIG_HOME=" + filepath.Join(temp, "config"),
		"XDG_CACHE_HOME=" + filepath.Join(temp, "cache"),
		"XDG_DATA_HOME=" + filepath.Join(temp, "data"),
		"XDG_STATE_HOME=" + filepath.Join(temp, "state"),
		"MISE_CONFIG_DIR=" + filepath.Join(temp, "mise-config"),
		"MISE_DATA_DIR=" + filepath.Join(temp, "mise-data"),
		"MISE_CACHE_DIR=" + filepath.Join(temp, "mise-cache"),
		"MISE_YES=1",
		"GIT_CONFIG_NOSYSTEM=1",
		"GIT_CONFIG_GLOBAL=/dev/null",
		"GIT_TERMINAL_PROMPT=0",
		"TMPDIR=" + temp,
		"NO_COLOR=1",
		"LC_ALL=C",
	}
	for _, key := range []string{"HTTPS_PROXY", "HTTP_PROXY", "ALL_PROXY", "NO_PROXY", "https_proxy", "http_proxy", "all_proxy", "no_proxy", "SSL_CERT_FILE", "SSL_CERT_DIR"} {
		if value, ok := os.LookupEnv(key); ok {
			env = append(env, key+"="+value)
		}
	}
	run := func(dir, program string, args ...string) (string, error) {
		cmd := exec.CommandContext(t.Context(), program, args...)
		cmd.Dir = dir
		cmd.Env = env
		output, err := cmd.CombinedOutput()
		return string(output), err
	}
	mustRun := func(dir, program string, args ...string) string {
		t.Helper()
		output, err := run(dir, program, args...)
		if err != nil {
			t.Fatalf("%s %v failed: %v\n%s", program, args, err, output)
		}
		return strings.TrimSpace(output)
	}
	source := mustRun(".", git, "rev-parse", "--show-toplevel")
	copyTrackedFiles(t, source, repo, mustRun(source, git, "ls-files", "-z"))
	mustRun(repo, git, "init", "--initial-branch=main")
	mustRun(repo, git, "config", "user.name", "Hook E2E")
	mustRun(repo, git, "config", "user.email", "hook-e2e@example.invalid")
	mustRun(repo, git, "config", "commit.gpgsign", "false")
	mustRun(repo, git, "add", ".")
	mustRun(repo, git, "commit", "-m", "test: establish clean baseline")
	mustRun(repo, mise, "trust")
	t.Log("Installing project tools and hooks into the isolated repository")
	t.Log(mustRun(repo, mise, "install"))

	fixture := "hook-e2e-fixture.txt"
	if err := os.WriteFile(filepath.Join(repo, fixture), []byte("Harmless test content.\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	mustRun(repo, git, "add", "--", fixture)
	t.Log(mustRun(repo, git, "commit", "-m", "test: accept clean content"))
	cleanHead := mustRun(repo, git, "rev-parse", "HEAD")
	secret := "aws_access_key_id = " + "AKIA" + "LALEMEL33243OLIA" + "\n"
	if err := os.WriteFile(filepath.Join(repo, fixture), []byte(secret), 0o644); err != nil {
		t.Fatal(err)
	}
	mustRun(repo, git, "add", "--", fixture)
	output, err := run(repo, git, "commit", "-m", "test: reject synthetic secret")
	if err == nil {
		t.Fatal("secret commit succeeded; the installed pre-commit hook did not reject it")
	}
	var exitErr *exec.ExitError
	if !errors.As(err, &exitErr) || exitErr.ExitCode() <= 0 {
		t.Fatalf("secret commit did not exit normally: %v\n%s", err, output)
	}
	for _, evidence := range []string{"gitleaks", "aws-access-token", fixture} {
		if !strings.Contains(strings.ToLower(output), evidence) {
			t.Fatalf("commit failed without gitleaks detection evidence %q:\n%s", evidence, output)
		}
	}
	if head := mustRun(repo, git, "rev-parse", "HEAD"); head != cleanHead {
		t.Fatalf("rejected commit changed HEAD from %s to %s", cleanHead, head)
	}
	if staged := mustRun(repo, git, "diff", "--cached", "--name-only"); staged != fixture {
		t.Fatalf("rejected secret should remain staged, got %q", staged)
	}
	t.Log("The installed hook rejected the synthetic secret and preserved HEAD")
}
