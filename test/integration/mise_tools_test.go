package integration

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

const miseToolUpdateFiles = ".github/scripts/update-mise-tools.sh\x00.github/scripts/mise_lock_plan.rb\x00mise.toml\x00mise.lock\x00go.mod\x00files/home/.config/mise/config.toml\x00files/home/.config/mise/config.home.toml\x00files/home/.config/mise/mise.lock\x00"

const miseToolStub = `#!/bin/bash
set -euo pipefail
[[ "$PWD" != "$EXPECTED_REPO" && -f go.mod && -f mise.lock && ! -e .git ]]
[[ "$MISE_SAFE" == 1 && "$MISE_LOCKFILE_AUTO_PRUNE" == false ]]
[[ "$MISE_AUTO_ENV" == false && "$MISE_ENV" == home ]]
[[ "$MISE_CEILING_PATHS" == "$(dirname "$PWD")" ]]
[[ -d "$MISE_SYSTEM_CONFIG_DIR" && -z "$(ls -A "$MISE_SYSTEM_CONFIG_DIR")" ]]
[[ -z "${MISE_GLOBAL_CONFIG_FILE+x}${MISE_CONFIG_FILE+x}${MISE_GLOBAL_CONFIG_ROOT+x}${MISE_SYSTEM_CONFIG_FILE+x}" ]]
[[ -z "${MISE_OVERRIDE_CONFIG_FILENAMES+x}${MISE_OVERRIDE_TOOL_VERSIONS_FILENAMES+x}" ]]
for name in MISE_DATA_DIR MISE_CACHE_DIR MISE_STATE_DIR MISE_SHIMS_DIR GEM_HOME GEM_PATH BUNDLE_USER_HOME BUNDLE_APP_CONFIG; do
  [[ "${!name}" == "$TMPDIR/"* && "${!name}" != "$HOME/"* ]]
done
printf '%s\n' "$MISE_SYSTEM_CONFIG_DIR" > "$SYSTEM_LOG"
if [[ "$*" == "install --locked ruby" ]]; then
  [[ "$MISE_DATA_DIR" == */runtime-data ]]
  [[ "$MISE_CONFIG_DIR" == "$PWD/files/home/.config/mise" ]]
  cmp "$MISE_CONFIG_DIR/config.toml" "$EXPECTED_REPO/files/home/.config/mise/config.toml"
  cmp "$MISE_CONFIG_DIR/config.home.toml" "$EXPECTED_REPO/files/home/.config/mise/config.home.toml"
  grep -F -q 'compile = false' "$MISE_CONFIG_DIR/config.toml"
  mkdir -p "$GEM_HOME"
  cp -R "$PARSER_GEMS/." "$GEM_HOME/"
  printf '%s\n' "$MISE_DATA_DIR" > "$RUNTIME_LOG"
  exit 0
fi
if [[ "$*" == "which ruby" ]]; then
  [[ "$MISE_DATA_DIR" == "$(cat "$RUNTIME_LOG")" ]]
  [[ "$MISE_CONFIG_DIR" == "$PWD/files/home/.config/mise" ]]
  printf '%s\n' "$PLANNER_RUBY"
  exit 0
fi
[[ "$MISE_DATA_DIR" == */tool-data && "$MISE_DATA_DIR" != "$(cat "$RUNTIME_LOG")" ]]
if [[ "$*" == "config get settings.minimum_release_age --file "* ]]; then
  grep -F -q 'minimum_release_age = "7d"' "${@: -1}"
  printf '%s\n' 7d
  exit 0
fi
[[ "$MISE_MINIMUM_RELEASE_AGE" == 7d ]]
scope=project
lock="$PWD/mise.lock"
sidecars="$PWD/.mise/locks"
if [[ " $* " == *" --global "* ]]; then
  scope=global
  [[ "$MISE_CONFIG_DIR" == "$PWD/files/home/.config/mise" ]]
  [[ -f "$MISE_CONFIG_DIR/config.toml" && -f "$MISE_CONFIG_DIR/config.home.toml" ]]
  lock="$MISE_CONFIG_DIR/mise.lock"
  sidecars="$MISE_CONFIG_DIR/locks"
else
  [[ -d "$MISE_CONFIG_DIR" && -z "$(ls -A "$MISE_CONFIG_DIR")" ]]
fi
printf '%s %s\n' "$scope" "$*" >> "$COMMAND_LOG"
if [[ "${FAIL_SCOPE:-}" == "$scope" ]]; then
  echo "$scope update failed" >&2
  exit 7
fi
if [[ "$1 $2" == "backends switch" ]]; then
  cp "$FIXTURE_DIR/$scope-migrated.lock" "$lock"
  if [[ "${CHANGE_PROFILE_LOCK:-}" == 1 ]]; then
    printf '%s\n' profile > "${lock%.lock}.home.lock"
  fi
  if [[ "${CHANGE_SIDECARS:-}" == 1 ]]; then
    rm -f "$sidecars/old.json"
    mkdir -p "$sidecars"
    printf '%s\n' new > "$sidecars/new.json"
  fi
elif [[ "$*" == *--dry-run* ]]; then
  if [[ "${MUTATE_SOURCE:-}" == 1 && "$scope" == global ]]; then
    printf '%s\n' concurrent > "$EXPECTED_REPO/.mise/locks/concurrent.json"
  fi
  if [[ "$*" == *"--minimum-release-age 0s"* ]]; then
    sed "s|@MAIN_LOCK@|${lock#/private}|g; s|@PROFILE_LOCK@|${lock%.lock}.home.lock|g" "$FIXTURE_DIR/$scope-fresh.json"
  else
    sed "s|@MAIN_LOCK@|${lock#/private}|g; s|@PROFILE_LOCK@|${lock%.lock}.home.lock|g" "$FIXTURE_DIR/$scope-aged.json"
  fi
elif [[ "$1" == lock && "$*" == *"--bump --json -- "* ]]; then
  cp "$FIXTURE_DIR/$scope-final.lock" "$lock"
  if [[ "$scope" == global && -n "${LATE_MUTATION_SCOPE:-}" ]]; then
    target="$PWD/mise.lock"
    if [[ "$LATE_MUTATION_SCOPE" == global ]]; then target="$PWD/files/home/.config/mise/mise.lock"; fi
    cp "$FIXTURE_DIR/late-mutation.lock" "$target"
  fi
else
  echo "unexpected mise command $*" >&2
  exit 9
fi
`

func parserRuntime(t *testing.T) (string, string) {
	t.Helper()
	which := exec.CommandContext(t.Context(), "mise", "which", "ruby")
	which.Dir = filepath.Join("..", "..")
	output, err := which.CombinedOutput()
	if err != nil {
		t.Fatalf("mise which ruby: %v\n%s", err, output)
	}
	ruby := strings.TrimSpace(string(output))
	if cache := os.Getenv("MISE_UPDATE_TEST_GEM_CACHE"); cache != "" {
		return ruby, cache
	}
	isolated := t.TempDir()
	gems := filepath.Join(isolated, "gems")
	cmd := exec.CommandContext(t.Context(), ruby, "-e", `require "bundler/inline"; gemfile do; source "https://rubygems.org"; gem "toml-rb", "= 6.0.0", require: "toml-rb"; end`)
	cmd.Env = append(os.Environ(), "GEM_HOME="+gems, "GEM_PATH="+gems,
		"BUNDLE_IGNORE_CONFIG=1", "BUNDLE_USER_HOME="+filepath.Join(isolated, "bundle"),
		"BUNDLE_USER_CACHE="+filepath.Join(isolated, "bundle/cache"), "BUNDLE_USER_CONFIG="+filepath.Join(isolated, "bundle/config"),
		"BUNDLE_USER_PLUGIN="+filepath.Join(isolated, "bundle/plugin"), "BUNDLE_GEMFILE=", "BUNDLE_PATH=",
		"BUNDLE_APP_CONFIG="+filepath.Join(isolated, "app"), "MISE_DATA_DIR="+filepath.Join(isolated, "mise"),
		"MISE_CACHE_DIR="+filepath.Join(isolated, "cache"), "MISE_STATE_DIR="+filepath.Join(isolated, "state"),
		"MISE_SHIMS_DIR="+filepath.Join(isolated, "shims"))
	if output, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("prepare parser: %v\n%s", err, output)
	}
	return ruby, gems
}

type toolUpdateFixture struct{ temp, repo, bin, ruby, gems string }

func newToolUpdateFixture(t *testing.T, ruby, gems string) toolUpdateFixture {
	t.Helper()
	temp, err := filepath.EvalSymlinks(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	fixture := toolUpdateFixture{temp: temp, repo: filepath.Join(temp, "repo"), bin: filepath.Join(temp, "bin"), ruby: ruby, gems: gems}
	copyTrackedFiles(t, filepath.Join("..", ".."), fixture.repo, miseToolUpdateFiles)
	writePolicyFixture(t, filepath.Join(fixture.bin, "mise"), miseToolStub)
	for _, scope := range []string{"project", "global"} {
		source := "mise.lock"
		if scope == "global" {
			source = "files/home/.config/mise/mise.lock"
		}
		contents := readPolicyLog(t, filepath.Join(fixture.repo, source))
		fixture.states(t, scope, contents, contents, contents, "[]", "[]")
	}
	for _, relative := range []string{".mise/locks/old.json", "files/home/.config/mise/locks/old.json", "installed/tool", "home/.local/share/mise/installs/sentinel", "home/.local/share/gem/sentinel", "home/.bundle/config"} {
		root := fixture.repo
		if strings.HasPrefix(relative, "home/") || strings.HasPrefix(relative, "installed/") {
			root = temp
		}
		writePolicyFixture(t, filepath.Join(root, relative), "original\n")
	}
	return fixture
}

func (f toolUpdateFixture) states(t *testing.T, scope, before, migrated, after, aged, fresh string) {
	t.Helper()
	relative := "mise.lock"
	if scope == "global" {
		relative = "files/home/.config/mise/mise.lock"
	}
	writePolicyFixture(t, filepath.Join(f.repo, relative), before)
	for name, contents := range map[string]string{scope + "-migrated.lock": migrated, scope + "-final.lock": after, scope + "-aged.json": aged, scope + "-fresh.json": fresh} {
		writePolicyFixture(t, filepath.Join(f.temp, name), contents)
	}
}

func (f toolUpdateFixture) run(t *testing.T, extra ...string) (string, error) {
	t.Helper()
	cmd := exec.CommandContext(t.Context(), "bash", filepath.Join(f.repo, ".github/scripts/update-mise-tools.sh"))
	cmd.Dir = f.temp
	cmd.Env = append([]string{"HOME=" + filepath.Join(f.temp, "home"), "PATH=" + f.bin + ":/usr/bin:/bin", "TMPDIR=" + f.temp,
		"EXPECTED_REPO=" + f.repo, "COMMAND_LOG=" + filepath.Join(f.temp, "commands"), "SYSTEM_LOG=" + filepath.Join(f.temp, "system"),
		"RUNTIME_LOG=" + filepath.Join(f.temp, "runtime"), "PLANNER_RUBY=" + f.ruby, "PARSER_GEMS=" + f.gems, "FIXTURE_DIR=" + f.temp,
		"MISE_LOCK_PR_TITLE_FILE=" + filepath.Join(f.temp, "title.txt"), "MISE_LOCK_PR_BODY_FILE=" + filepath.Join(f.temp, "body.md"),
		"MISE_SAFE=0", "MISE_LOCKFILE_AUTO_PRUNE=true", "MISE_CONFIG_DIR=/unrelated/global", "MISE_SYSTEM_CONFIG_DIR=/unrelated/system",
		"MISE_CEILING_PATHS=/unrelated/ancestor", "MISE_AUTO_ENV=true", "MISE_ENV=work,macos",
		"MISE_GLOBAL_CONFIG_FILE=/unrelated/global.toml", "MISE_CONFIG_FILE=/unrelated/config.toml", "MISE_GLOBAL_CONFIG_ROOT=/unrelated/root",
		"MISE_SYSTEM_CONFIG_FILE=/unrelated/system.toml", "MISE_OVERRIDE_CONFIG_FILENAMES=unrelated.toml", "MISE_OVERRIDE_TOOL_VERSIONS_FILENAMES=unrelated-versions",
		"MISE_MINIMUM_RELEASE_AGE=1h", "MISE_DATA_DIR=/unrelated/data", "MISE_CACHE_DIR=/unrelated/cache", "GEM_HOME=/unrelated/gems", "GEM_PATH=/unrelated/gems"}, extra...)
	output, err := cmd.CombinedOutput()
	if system, readErr := os.ReadFile(filepath.Join(f.temp, "system")); readErr == nil {
		if _, statErr := os.Stat(strings.TrimSpace(string(system))); !os.IsNotExist(statErr) {
			t.Fatalf("temporary state not removed: %v", statErr)
		}
	}
	for _, relative := range []string{"installed/tool", "home/.local/share/mise/installs/sentinel", "home/.local/share/gem/sentinel", "home/.bundle/config"} {
		if text := readPolicyLog(t, filepath.Join(f.temp, relative)); text != "original\n" {
			t.Fatalf("operator state changed: %s", relative)
		}
	}
	return string(output), err
}

func toolLock(name, version, backend, specifier string) string {
	return fmt.Sprintf("lockfile_version = 3\n\n[[tools.%q]]\nversion = %q\nbackend = %q\nspecifiers = [%q]\n\n[tools.%q.\"platforms.linux-x64\"]\nchecksum = \"sha256:linux\"\n\n[tools.%q.\"platforms.macos-arm64\"]\nchecksum = \"sha256:macos\"\n", name, version, backend, specifier, name, name)
}

func toolChanges(lock, name, backend string, old, new []string) string {
	contents, _ := json.Marshal([]map[string]any{{"name": name, "backend": backend, "lockfile": lock, "old_versions": old, "new_versions": new}})
	return string(contents)
}

func requireText(t *testing.T, text string, wants ...string) {
	t.Helper()
	for _, want := range wants {
		if !strings.Contains(text, want) {
			t.Fatalf("missing %q:\n%s", want, text)
		}
	}
}

func TestMiseToolUpdate(t *testing.T) {
	ruby, gems := parserRuntime(t)
	oldBackend, newBackend := "aqua:owner/widget", "github:owner/widget"
	old := toolLock("widget", "1.0.0", oldBackend, "latest")
	migrated := toolLock("widget", "1.0.0", newBackend, "latest")
	adopted := toolLock("widget", "1.1.0", newBackend, "latest")
	aged := toolChanges("@MAIN_LOCK@", "widget", newBackend, []string{"1.0.0"}, []string{"1.1.0"})
	fresh := toolChanges("@MAIN_LOCK@", "widget", newBackend, []string{"1.0.0"}, []string{"1.2.0"})
	for _, scope := range []string{"project", "global"} {
		t.Run("native-profile-candidates-"+scope, func(t *testing.T) {
			f := newToolUpdateFixture(t, ruby, gems)
			gum := toolLock("gum", "2.0.2", "aqua:charmbracelet/gum", "latest")
			before := old + strings.TrimPrefix(gum, "lockfile_version = 3\n\n")
			after := migrated + strings.TrimPrefix(gum, "lockfile_version = 3\n\n")
			profile := toolChanges("@PROFILE_LOCK@", "gum", "aqua:charmbracelet/gum", []string{}, []string{"2.0.2"})
			f.states(t, scope, before, after, after, profile, profile)
			output, err := f.run(t, "CHANGE_PROFILE_LOCK=1")
			if err != nil {
				t.Fatalf("native profile candidates: %v\n%s", err, output)
			}
			requireText(t, output, "widget backend", "`aqua:owner/widget` | `github:owner/widget`")
			if strings.Contains(output, "gum") || strings.Contains(readPolicyLog(t, filepath.Join(f.temp, "commands")), "--bump --json --") {
				t.Fatalf("profile candidate selected or reported:\n%s", output)
			}
			for _, profilePath := range []string{"mise.home.lock", "files/home/.config/mise/mise.home.lock"} {
				if _, err := os.Stat(filepath.Join(f.repo, profilePath)); !os.IsNotExist(err) {
					t.Fatalf("profile lock published: %s: %v", profilePath, err)
				}
			}
		})
		for _, candidates := range []string{"aged", "fresh", "both"} {
			t.Run("profile-name-collision-"+scope+"-"+candidates, func(t *testing.T) {
				f := newToolUpdateFixture(t, ruby, gems)
				profile := toolChanges("@PROFILE_LOCK@", "widget", newBackend, []string{"1.0.0"}, []string{"9.0.0"})
				joined := func(main string) string {
					return strings.TrimSuffix(main, "]") + "," + strings.TrimPrefix(profile, "[")
				}
				scopeAged, scopeFresh := aged, fresh
				if candidates != "fresh" {
					scopeAged = joined(scopeAged)
				}
				if candidates != "aged" {
					scopeFresh = joined(scopeFresh)
				}
				f.states(t, scope, old, migrated, adopted, scopeAged, scopeFresh)
				output, err := f.run(t)
				if err != nil {
					t.Fatalf("main/profile collision: %v\n%s", err, output)
				}
				requireText(t, output, "`1.0.0` → `1.1.0` | `1.2.0`", "`aqua:owner/widget` | `github:owner/widget`")
				if strings.Contains(output, "9.0.0") {
					t.Fatalf("profile candidate reported:\n%s", output)
				}
			})
		}
	}
	t.Run("missing-candidate-lockfile", func(t *testing.T) {
		f := newToolUpdateFixture(t, ruby, gems)
		missingLock := strings.ReplaceAll(aged, `"lockfile":"@MAIN_LOCK@",`, "")
		f.states(t, "project", old, migrated, adopted, missingLock, fresh)
		output, err := f.run(t)
		if err == nil {
			t.Fatalf("accepted missing candidate lockfile:\n%s", output)
		}
		requireText(t, output, "invalid candidate lockfile")
		if readPolicyLog(t, filepath.Join(f.repo, "mise.lock")) != old {
			t.Fatal("missing candidate lockfile published lock")
		}
	})
	t.Run("unlocked-main-candidates", func(t *testing.T) {
		f := newToolUpdateFixture(t, ruby, gems)
		unlocked := toolChanges("@MAIN_LOCK@", "widget", newBackend, []string{}, []string{"1.1.0"})
		unknown := toolChanges("@MAIN_LOCK@", "unlocked", "core:unlocked", []string{}, []string{"2.0.0"})
		candidates := strings.TrimSuffix(unlocked, "]") + "," + strings.TrimPrefix(unknown, "[")
		f.states(t, "project", old, migrated, migrated, candidates, candidates)
		output, err := f.run(t)
		if err != nil {
			t.Fatalf("unlocked candidates: %v\n%s", err, output)
		}
		requireText(t, output, "widget backend")
		if strings.Contains(readPolicyLog(t, filepath.Join(f.temp, "commands")), "--bump --json --") || strings.Contains(output, "1.1.0") || strings.Contains(output, "2.0.0") {
			t.Fatalf("unlocked candidate selected or reported:\n%s", output)
		}
	})
	t.Run("backend-only-both-scopes-repeat", func(t *testing.T) {
		f := newToolUpdateFixture(t, ruby, gems)
		for _, scope := range []string{"project", "global"} {
			f.states(t, scope, old, migrated, migrated, "[]", "[]")
		}
		output, err := f.run(t, "CHANGE_SIDECARS=1")
		if err != nil {
			t.Fatalf("update: %v\n%s", err, output)
		}
		body := readPolicyLog(t, filepath.Join(f.temp, "body.md"))
		title := readPolicyLog(t, filepath.Join(f.temp, "title.txt"))
		requireText(t, body, "| Package | Version | Old backend | New backend | Scope |", "| [widget](https://github.com/owner/widget) | `1.0.0` | `aqua:owner/widget` | `github:owner/widget` | Project, Global |")
		if title != "chore(mise): update widget backend\n" || strings.Contains(body, "### Release notes") || strings.Contains(body, "| Type |") {
			t.Fatalf("backend report:\n%s\n%s", title, body)
		}
		for _, relative := range []string{".mise/locks", "files/home/.config/mise/locks"} {
			if _, err := os.Stat(filepath.Join(f.repo, relative, "old.json")); !os.IsNotExist(err) {
				t.Fatalf("old sidecar remains: %v", err)
			}
			if got := readPolicyLog(t, filepath.Join(f.repo, relative, "new.json")); got != "new\n" {
				t.Fatal(got)
			}
		}
		for _, scope := range []string{"project", "global"} {
			f.states(t, scope, migrated, migrated, migrated, "[]", "[]")
		}
		output, err = f.run(t)
		if err != nil {
			t.Fatalf("repeat: %v\n%s", err, output)
		}
		requireText(t, output, "chore(mise): update tools", "No tool changes.")
	})
	t.Run("version-only", func(t *testing.T) {
		f := newToolUpdateFixture(t, ruby, gems)
		f.states(t, "project", migrated, migrated, adopted, aged, fresh)
		output, err := f.run(t)
		if err != nil {
			t.Fatalf("update: %v\n%s", err, output)
		}
		requireText(t, output, "| Package | Type | Update | Change | Pending | Scope |", "| [widget](https://github.com/owner/widget) | tools | minor | `1.0.0` → `1.1.0` | `1.2.0` | Project |", "- [widget 1.1.0](https://github.com/owner/widget/releases) (Project)")
		if strings.Contains(output, "### Backend changes") || strings.Contains(output, "widget 1.2.0]") {
			t.Fatal(output)
		}
	})
	t.Run("same-tool-and-different-tool", func(t *testing.T) {
		f := newToolUpdateFixture(t, ruby, gems)
		f.states(t, "project", old, strings.ReplaceAll(migrated, newBackend, "github:newowner/widget"), strings.ReplaceAll(adopted, newBackend, "github:newowner/widget"), aged, fresh)
		otherOld := toolLock("other", "2.0.0", "aqua:elsewhere/other", "2")
		otherNew := toolLock("other", "2.0.0", "github:elsewhere/other", "2")
		f.states(t, "global", otherOld, otherNew, otherNew, "[]", "[]")
		output, err := f.run(t)
		if err != nil {
			t.Fatalf("mixed: %v\n%s", err, output)
		}
		requireText(t, output, "chore(mise): update widget 1.1.0, other backend\n", "| [widget](https://github.com/newowner/widget) | `1.0.0` → `1.1.0` | `aqua:owner/widget` | `github:newowner/widget` | Project |", "| [other](https://github.com/elsewhere/other) | `2.0.0` |", "- [widget 1.1.0](https://github.com/newowner/widget/releases) (Project)")
		if strings.Contains(output, "(+") {
			t.Fatal(output)
		}
	})
	t.Run("no-pending-column", func(t *testing.T) {
		f := newToolUpdateFixture(t, ruby, gems)
		f.states(t, "project", migrated, migrated, adopted, aged, aged)
		output, err := f.run(t)
		if err != nil {
			t.Fatalf("version update: %v\n%s", err, output)
		}
		requireText(t, output, "| Package | Type | Update | Change | Scope |")
		if strings.Contains(output, "| Pending |") {
			t.Fatal(output)
		}
	})
	t.Run("no-rollback", func(t *testing.T) {
		f := newToolUpdateFixture(t, ruby, gems)
		tooNew := toolLock("widget", "1.3.0", oldBackend, "latest")
		after := toolLock("widget", "1.3.0", newBackend, "latest")
		f.states(t, "project", tooNew, after, after, toolChanges("@MAIN_LOCK@", "widget", newBackend, []string{"1.3.0"}, []string{"1.1.0"}), toolChanges("@MAIN_LOCK@", "widget", newBackend, []string{"1.3.0"}, []string{"1.3.0"}))
		output, err := f.run(t)
		if err != nil {
			t.Fatalf("no rollback: %v\n%s", err, output)
		}
		requireText(t, output, "| `1.3.0` | `aqua:owner/widget` | `github:owner/widget` |")
		if got := readPolicyLog(t, filepath.Join(f.repo, "mise.lock")); got != after {
			t.Fatal("rolled back lock")
		}
	})
	t.Run("scope-differences", func(t *testing.T) {
		f := newToolUpdateFixture(t, ruby, gems)
		f.states(t, "project", old, migrated, migrated, "[]", "[]")
		f.states(t, "global", strings.ReplaceAll(old, "1.0.0", "2.0.0"), strings.ReplaceAll(migrated, "1.0.0", "2.0.0"), strings.ReplaceAll(migrated, "1.0.0", "2.0.0"), "[]", "[]")
		output, err := f.run(t)
		if err != nil {
			t.Fatalf("scopes: %v\n%s", err, output)
		}
		requireText(t, output, "| `1.0.0` | `aqua:owner/widget` | `github:owner/widget` | Project |", "| `2.0.0` | `aqua:owner/widget` | `github:owner/widget` | Global |")
		if strings.Contains(output, "Project, Global") {
			t.Fatal(output)
		}
	})

	t.Run("scope-backend-differences", func(t *testing.T) {
		f := newToolUpdateFixture(t, ruby, gems)
		f.states(t, "project", old, migrated, migrated, "[]", "[]")
		different := strings.ReplaceAll(migrated, newBackend, "github:elsewhere/widget")
		f.states(t, "global", old, different, different, "[]", "[]")
		output, err := f.run(t)
		if err != nil {
			t.Fatalf("scope backend differences: %v\n%s", err, output)
		}
		requireText(t, output, "`github:owner/widget` | Project |", "`github:elsewhere/widget` | Global |")
		if strings.Contains(output, "Project, Global") {
			t.Fatal(output)
		}
	})
	t.Run("dry-run", func(t *testing.T) {
		f := newToolUpdateFixture(t, ruby, gems)
		f.states(t, "project", old, migrated, adopted, aged, fresh)
		globalBefore := readPolicyLog(t, filepath.Join(f.repo, "files/home/.config/mise/mise.lock"))
		output, err := f.run(t, "MISE_LOCK_DRY_RUN=1", "CHANGE_SIDECARS=1")
		if err != nil {
			t.Fatalf("dry run: %v\n%s", err, output)
		}
		requireText(t, output, "`1.0.0` → `1.1.0`", "`aqua:owner/widget` | `github:owner/widget`")
		if readPolicyLog(t, filepath.Join(f.repo, "mise.lock")) != old || readPolicyLog(t, filepath.Join(f.repo, "files/home/.config/mise/mise.lock")) != globalBefore {
			t.Fatal("dry run published lock")
		}
		for _, path := range []string{".mise/locks/old.json", "files/home/.config/mise/locks/old.json"} {
			if readPolicyLog(t, filepath.Join(f.repo, path)) != "original\n" {
				t.Fatal("dry run changed sidecars")
			}
		}
		dryReport := readPolicyLog(t, filepath.Join(f.temp, "body.md"))
		output, err = f.run(t, "CHANGE_SIDECARS=1")
		if err != nil {
			t.Fatalf("apply: %v\n%s", err, output)
		}
		if got := readPolicyLog(t, filepath.Join(f.temp, "body.md")); got != dryReport {
			t.Fatalf("dry/apply report mismatch:\n%s\n%s", dryReport, got)
		}
	})
	for _, scenario := range []string{"global-failure", "migration-version", "unexpected-final", "source-change"} {
		t.Run(scenario, func(t *testing.T) {
			f := newToolUpdateFixture(t, ruby, gems)
			f.states(t, "project", old, migrated, adopted, aged, fresh)
			globalBefore := readPolicyLog(t, filepath.Join(f.repo, "files/home/.config/mise/mise.lock"))
			extra := []string{"CHANGE_SIDECARS=1"}
			want := ""
			switch scenario {
			case "global-failure":
				extra = append(extra, "FAIL_SCOPE=global")
				want = "global update failed"
			case "migration-version":
				f.states(t, "project", old, adopted, adopted, aged, fresh)
				want = "backend migration changed version"
			case "unexpected-final":
				f.states(t, "project", old, migrated, strings.ReplaceAll(adopted, "1.1.0", "9.0.0"), aged, fresh)
				want = "unexpected final version"
			case "source-change":
				extra = append(extra, "MUTATE_SOURCE=1")
				want = "source artifacts changed during update"
			}
			output, err := f.run(t, extra...)
			if err == nil {
				t.Fatalf("accepted %s:\n%s", scenario, output)
			}
			requireText(t, output, want)
			if readPolicyLog(t, filepath.Join(f.repo, "mise.lock")) != old || readPolicyLog(t, filepath.Join(f.repo, "files/home/.config/mise/mise.lock")) != globalBefore {
				t.Fatal("failure published a lock")
			}
			if readPolicyLog(t, filepath.Join(f.repo, ".mise/locks/old.json")) != "original\n" {
				t.Fatal("failure published sidecar deletion")
			}
			if _, err := os.Stat(filepath.Join(f.temp, "title.txt")); !os.IsNotExist(err) {
				t.Fatalf("failure published PR report: %v", err)
			}
		})
	}

	for _, scope := range []string{"project", "global"} {
		t.Run("late-mutation-"+scope, func(t *testing.T) {
			f := newToolUpdateFixture(t, ruby, gems)
			for _, scope := range []string{"project", "global"} {
				f.states(t, scope, old, migrated, adopted, aged, fresh)
			}
			writePolicyFixture(t, filepath.Join(f.temp, "late-mutation.lock"), strings.ReplaceAll(adopted, "1.1.0", "9.0.0"))
			output, err := f.run(t, "LATE_MUTATION_SCOPE="+scope, "CHANGE_SIDECARS=1")
			if err == nil {
				t.Fatalf("accepted late %s mutation:\n%s", scope, output)
			}
			requireText(t, output, "unexpected final version")
			for _, relative := range []string{"mise.lock", "files/home/.config/mise/mise.lock"} {
				if readPolicyLog(t, filepath.Join(f.repo, relative)) != old {
					t.Fatalf("failure published lock %s", relative)
				}
			}
			for _, relative := range []string{".mise/locks", "files/home/.config/mise/locks"} {
				if readPolicyLog(t, filepath.Join(f.repo, relative, "old.json")) != "original\n" {
					t.Fatalf("failure deleted sidecar %s", relative)
				}
				if _, err := os.Stat(filepath.Join(f.repo, relative, "new.json")); !os.IsNotExist(err) {
					t.Fatalf("failure published sidecar %s: %v", relative, err)
				}
			}
			for _, report := range []string{"title.txt", "body.md"} {
				if _, err := os.Stat(filepath.Join(f.temp, report)); !os.IsNotExist(err) {
					t.Fatalf("failure published report %s: %v", report, err)
				}
			}
		})
	}
	for _, candidate := range []string{"aged", "fresh", "fresh-only"} {
		t.Run("ambiguous-"+candidate+"-candidates", func(t *testing.T) {
			f := newToolUpdateFixture(t, ruby, gems)
			one := toolLock("widget", "1.0.0", oldBackend, "1")
			two := toolLock("widget", "1.0.0", oldBackend, "latest")
			before := one + strings.TrimPrefix(two, "lockfile_version = 3\n\n")
			middle := strings.ReplaceAll(before, oldBackend, newBackend)
			after := strings.ReplaceAll(middle, "1.0.0", "1.1.0")
			unambiguous := toolChanges("@MAIN_LOCK@", "widget", newBackend, []string{"1.0.0", "1.0.0"}, []string{"1.1.0", "1.1.0"})
			ambiguous := toolChanges("@MAIN_LOCK@", "widget", newBackend, []string{"1.0.0", "1.0.0"}, []string{"1.1.0", "2.0.0"})
			aged, fresh := unambiguous, unambiguous
			switch candidate {
			case "aged":
				aged = ambiguous
				after = toolLock("widget", "1.1.0", newBackend, "1") + strings.TrimPrefix(toolLock("widget", "2.0.0", newBackend, "latest"), "lockfile_version = 3\n\n")
			case "fresh":
				fresh = ambiguous
			case "fresh-only":
				aged, fresh, after = "[]", ambiguous, middle
			}
			f.states(t, "project", before, middle, after, aged, fresh)
			output, err := f.run(t)
			if err == nil {
				t.Fatalf("accepted ambiguous %s candidates:\n%s", candidate, output)
			}
			requireText(t, output, "ambiguous version candidate")
			if readPolicyLog(t, filepath.Join(f.repo, "mise.lock")) != before {
				t.Fatal("ambiguity published lock")
			}
			for _, report := range []string{"title.txt", "body.md"} {
				if _, err := os.Stat(filepath.Join(f.temp, report)); !os.IsNotExist(err) {
					t.Fatalf("ambiguity published report %s: %v", report, err)
				}
			}
		})
	}

	t.Run("unambiguous-repeated-versions", func(t *testing.T) {
		f := newToolUpdateFixture(t, ruby, gems)
		one := toolLock("widget", "1.0.0", oldBackend, "1")
		two := toolLock("widget", "1.0.0", oldBackend, "latest")
		before := one + strings.TrimPrefix(two, "lockfile_version = 3\n\n")
		middle := strings.ReplaceAll(before, oldBackend, newBackend)
		after := strings.ReplaceAll(middle, "1.0.0", "1.1.0")
		aged := toolChanges("@MAIN_LOCK@", "widget", newBackend, []string{"1.0.0", "1.0.0"}, []string{"1.1.0", "1.1.0"})
		fresh := toolChanges("@MAIN_LOCK@", "widget", newBackend, []string{"1.0.0", "1.0.0"}, []string{"1.2.0", "1.2.0"})
		f.states(t, "project", before, middle, after, aged, fresh)
		output, err := f.run(t)
		if err != nil {
			t.Fatalf("unambiguous repeated versions: %v\n%s", err, output)
		}
		requireText(t, output, "`1.0.0`, `1.0.0` → `1.1.0`, `1.1.0`", "`1.2.0`, `1.2.0`")
	})

	t.Run("quoted-multiple-bindings", func(t *testing.T) {
		f := newToolUpdateFixture(t, ruby, gems)
		name := "namespace/widget.with.dot"
		joined := func(a, b string) string { return a + strings.TrimPrefix(b, "lockfile_version = 3\n\n") }
		oldOne := toolLock(name, "v1.0.0", oldBackend, "1")
		oldTwo := toolLock(name, "2.0.0", oldBackend, "2")
		newOne := toolLock(name, "v1.0.0", newBackend, "1")
		newTwo := toolLock(name, "2.0.0", newBackend, "2")
		before := joined(oldOne, oldTwo)
		middle := joined(newTwo, newOne)
		after := joined(strings.ReplaceAll(newTwo, "2.0.0", "2.1.0"), strings.ReplaceAll(newOne, "v1.0.0", "v1.1.0"))
		aged := toolChanges("@MAIN_LOCK@", name, newBackend, []string{"v1.0.0", "2.0.0"}, []string{"v1.1.0", "2.1.0"})
		fresh := toolChanges("@MAIN_LOCK@", name, newBackend, []string{"v1.0.0", "2.0.0"}, []string{"v1.2.0", "2.2.0"})
		f.states(t, "project", before, middle, after, aged, fresh)
		output, err := f.run(t)
		if err != nil {
			t.Fatalf("multi-bindings: %v\n%s", err, output)
		}
		requireText(t, output, "`v1.0.0`, `2.0.0` → `v1.1.0`, `2.1.0`", "`v1.2.0`, `2.2.0`", "namespace/widget.with.dot")
	})

	t.Run("multiple-binding-scope-merge", func(t *testing.T) {
		f := newToolUpdateFixture(t, ruby, gems)
		joined := func(a, b string) string { return a + strings.TrimPrefix(b, "lockfile_version = 3\n\n") }
		one := toolLock("widget", "1.0.0", oldBackend, "1")
		two := toolLock("widget", "2.0.0", oldBackend, "2")
		before := joined(one, two)
		reverse := joined(two, one)
		projectAfter := strings.ReplaceAll(before, oldBackend, newBackend)
		globalAfter := strings.ReplaceAll(reverse, oldBackend, newBackend)
		f.states(t, "project", before, projectAfter, projectAfter, "[]", "[]")
		f.states(t, "global", reverse, globalAfter, globalAfter, "[]", "[]")
		output, err := f.run(t)
		if err != nil {
			t.Fatalf("multi-binding scope merge: %v\n%s", err, output)
		}
		requireText(t, output, "| `1.0.0`, `2.0.0` |", "| Project, Global |")
	})
	for _, identity := range []string{"missing", "duplicate", "changed"} {
		t.Run("ambiguous-"+identity, func(t *testing.T) {
			f := newToolUpdateFixture(t, ruby, gems)
			one := toolLock("widget", "1.0.0", oldBackend, "1")
			two := toolLock("widget", "2.0.0", oldBackend, "2")
			before := one + strings.TrimPrefix(two, "lockfile_version = 3\n\n")
			switch identity {
			case "missing":
				before = strings.ReplaceAll(before, "specifiers = [\"1\"]", "specifiers = []")
			case "duplicate":
				before = strings.ReplaceAll(before, "specifiers = [\"2\"]", "specifiers = [\"1\"]")
			}
			middle := strings.ReplaceAll(before, oldBackend, newBackend)
			if identity == "changed" {
				middle = strings.ReplaceAll(middle, "specifiers = [\"2\"]", "specifiers = [\"3\"]")
			}
			f.states(t, "project", before, middle, middle, "[]", "[]")
			output, err := f.run(t)
			if err == nil {
				t.Fatalf("accepted %s identity", identity)
			}
			if identity == "changed" {
				requireText(t, output, "request identities changed")
			} else {
				requireText(t, output, "ambiguous request identity")
			}
			if readPolicyLog(t, filepath.Join(f.repo, "mise.lock")) != before {
				t.Fatal("ambiguity published lock")
			}
		})
	}
	t.Run("single-binding-specifier-cleanup", func(t *testing.T) {
		f := newToolUpdateFixture(t, ruby, gems)
		cleaned := strings.ReplaceAll(migrated, "specifiers = [\"latest\"]", "specifiers = []")
		f.states(t, "project", old, cleaned, cleaned, "[]", "[]")
		output, err := f.run(t)
		if err != nil {
			t.Fatalf("single binding cleanup: %v\n%s", err, output)
		}
		requireText(t, output, "widget backend")
	})
	t.Run("real-records-and-platforms", func(t *testing.T) {
		f := newToolUpdateFixture(t, ruby, gems)
		project := readPolicyLog(t, filepath.Join(f.repo, "mise.lock"))
		global := readPolicyLog(t, filepath.Join(f.repo, "files/home/.config/mise/mise.lock"))
		projectAfter := strings.ReplaceAll(project, "aqua:gitleaks/gitleaks", "github:gitleaks/gitleaks")
		globalAfter := strings.ReplaceAll(global, "aqua:FiloSottile/age", "github:FiloSottile/age")
		f.states(t, "project", project, projectAfter, projectAfter, "[]", "[]")
		f.states(t, "global", global, globalAfter, globalAfter, "[]", "[]")
		output, err := f.run(t)
		if err != nil {
			t.Fatalf("real locks: %v\n%s", err, output)
		}
		if readPolicyLog(t, filepath.Join(f.repo, "mise.lock")) != projectAfter || readPolicyLog(t, filepath.Join(f.repo, "files/home/.config/mise/mise.lock")) != globalAfter {
			t.Fatal("backend migration lost real lock records")
		}
		requireText(t, project, "[[tools.go]]", "platforms.linux-x64", "platforms.macos-arm64")
	})
}

func TestMiseToolVersionPolicy(t *testing.T) {
	which := exec.CommandContext(t.Context(), "mise", "which", "ruby")
	which.Dir = filepath.Join("..", "..")
	output, err := which.CombinedOutput()
	if err != nil {
		t.Fatalf("mise which ruby: %v\n%s", err, output)
	}
	ruby := strings.TrimSpace(string(output))
	temp := t.TempDir()
	aged := `[
 {"lockfile":"@MAIN_LOCK@","name":"bun","backend":"core:bun","old_versions":["v1.4.3"],"new_versions":["v1.4.4"]},
 {"lockfile":"@MAIN_LOCK@","name":"ruby","backend":"core:ruby","old_versions":["3.4.1"],"new_versions":["4.0.0"]},
 {"lockfile":"@MAIN_LOCK@","name":"shellcheck","backend":"github:koalaman/shellcheck","old_versions":["0.10.0"],"new_versions":["0.11.0"]},
 {"lockfile":"@MAIN_LOCK@","name":"rumdl","backend":"github:rvben/rumdl","old_versions":["0.3.0"],"new_versions":["0.2.79"]},
 {"lockfile":"@MAIN_LOCK@","name":"ref","backend":"core:ref","old_versions":["main"],"new_versions":["next"]},
 {"lockfile":"@MAIN_LOCK@","name":"go","backend":"core:go","old_versions":["1.27.1"],"new_versions":[]}
 ]`
	fresh := `[{"lockfile":"@MAIN_LOCK@","name":"bun","backend":"core:bun","old_versions":["v1.4.3"],"new_versions":["v1.4.5"]},{"lockfile":"@MAIN_LOCK@","name":"hk","backend":"github:jdx/hk","old_versions":["2.7.0"],"new_versions":["2.8.1"]}]`
	snapshot := `{"bun":[{"version":"v1.4.3"}],"ruby":[{"version":"3.4.1"}],"shellcheck":[{"version":"0.10.0"}],"rumdl":[{"version":"0.3.0"}],"ref":[{"version":"main"}],"go":[{"version":"1.27.1"}]}`
	for name, contents := range map[string]string{"aged.json": aged, "fresh.json": fresh, "snapshot.json": snapshot} {
		writePolicyFixture(t, filepath.Join(temp, name), strings.ReplaceAll(contents, "@MAIN_LOCK@", filepath.Join(temp, "mise.lock")))
	}
	planner, err := filepath.Abs(filepath.Join("..", "..", ".github/scripts/mise_lock_plan.rb"))
	if err != nil {
		t.Fatal(err)
	}
	cmd := exec.CommandContext(t.Context(), ruby, planner, "plan", "--scope", "project", "--lock", filepath.Join(temp, "mise.lock"), "--aged", filepath.Join(temp, "aged.json"), "--fresh", filepath.Join(temp, "fresh.json"), "--snapshot", filepath.Join(temp, "snapshot.json"), "--out", filepath.Join(temp, "plan.json"))
	cmd.Env = []string{"PATH=/usr/bin:/bin", "HOME=" + temp, "GEM_HOME=" + filepath.Join(temp, "empty-gems"), "GEM_PATH=" + filepath.Join(temp, "empty-gems")}
	output, err = cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("planner: %v\n%s", err, output)
	}
	if string(output) != "bun\nruby\nshellcheck\n" {
		t.Fatalf("forward selections = %q", output)
	}
	plan := readPolicyLog(t, filepath.Join(temp, "plan.json"))
	requireText(t, plan, `"pending":["v1.4.5"]`, `"update":"major"`, `"update":"minor"`, `"update":"patch"`)
	if _, err := os.Stat(filepath.Join(temp, "empty-gems")); !os.IsNotExist(err) {
		t.Fatalf("JSON planning loaded parser dependency: %v", err)
	}
}
