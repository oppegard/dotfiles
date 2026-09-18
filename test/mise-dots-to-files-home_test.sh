#!/usr/bin/env bash

set -euo pipefail

repository="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
manifest="$repository/mise/mise-dots-to-files-home.tsv"
temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/mise-dots-layout-test.XXXXXXXX")"
home_marker='~'
trap 'rm -rf "$temporary_directory"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_link() {
  local target="$1" source="$2"
  [[ -L "$target" && -e "$target" && "$target" -ef "$source" ]] ||
    fail "$target is not linked to $source"
}

assert_compatibility_tree() {
  local count old_count=0 new_count=0 old_file new_file
  local scope target old_rel new_rel candidate suffix found old_mode new_mode
  count="$(awk -F '\t' '$1 !~ /^#/ && NF { count++ } END { print count + 0 }' "$manifest")"
  [[ "$count" -eq 41 ]] || fail "expected 41 manifest rows; found $count"

  while IFS= read -r -d '' old_file; do
    old_count=$((old_count + 1))
    found=false
    while IFS=$'\t' read -r scope target old_rel new_rel _mode; do
      [[ -z "$scope" || "$scope" == \#* ]] && continue
      if [[ "$old_file" == "$old_rel" ]]; then
        candidate="$new_rel"
      elif [[ "$old_file" == "$old_rel"/* ]]; then
        suffix="${old_file#"$old_rel"/}"
        candidate="$new_rel/$suffix"
      else
        continue
      fi
      [[ -f "$repository/$candidate" || -L "$repository/$candidate" ]] ||
        fail "missing compatibility source for $old_file: $candidate"
      cmp -s "$repository/$old_file" "$repository/$candidate" ||
        fail "compatibility source differs for $old_file"
      old_mode="$(git -C "$repository" ls-files -s -- "$old_file" | awk '{print $1}')"
      new_mode="$(stat_mode "$repository/$candidate")"
      case "$old_mode" in
        100755) [[ "$new_mode" == 755 ]] || fail "executable mode changed for $old_file" ;;
        100644) [[ "$new_mode" == 644 ]] || fail "file mode changed for $old_file" ;;
        *) fail "unexpected Git mode for $old_file: $old_mode" ;;
      esac
      found=true
      break
    done < "$manifest"
    "$found" || fail "manifest does not cover $old_file"
  done < <(git -C "$repository" ls-files -z 'mise-dots/**')

  while IFS= read -r -d '' new_file; do
    : "$new_file"
    new_count=$((new_count + 1))
  done < <(find "$repository/files" \( -type f -o -type l \) -print0)
  [[ "$new_count" -eq "$old_count" ]] ||
    fail "compatibility tree has $new_count entries; expected $old_count"
}

stat_mode() {
  if [[ "$(uname -s)" == Darwin ]]; then
    stat -f '%Lp' "$1"
  else
    stat -c '%a' "$1"
  fi
}

write_fixture_config() {
  local fixture="$1" case_name="$2" sublime_target platform_entries copy_entry
  if [[ "$case_name" == macos ]]; then
    sublime_target="$home_marker/Library/Application Support/Sublime Text 3/Packages/User"
    platform_entries=$(cat <<EOF
"~/.local/bin/fix-tahoe-focus" = "$fixture/files/home/.local/bin/fix-tahoe-focus"
"~/.local/bin/try" = "$fixture/files/home/.local/bin/try-darwin-aarch64"
EOF
)
    copy_entry="\"~/Library/Application Support/Rectangle Pro/RectangleProConfig.json\" = { source = \"$fixture/files/home/Library/Application Support/Rectangle Pro/RectangleProConfig.json\", mode = \"copy\" }"
  else
    sublime_target="$home_marker/.config/sublime-text/Packages/User"
    platform_entries=$(cat <<EOF
"~/.local/bin/screen" = "$fixture/files/home/.local/bin/screen-5.0.1"
"~/.local/bin/try" = "$fixture/files/home/.local/bin/try-linux-x86_64"
EOF
)
    copy_entry=""
  fi

  cat > "$fixture/mise.toml" <<EOF
[settings]
experimental = true
dotfiles.default_mode = "symlink"

[dotfiles]
"~/.bashrc" = "$fixture/files/home/.bashrc"
"~/.config/git" = { source = "$fixture/files/home/.config/git", mode = "symlink-each", manifest = "git" }
"~/.config/shell" = { source = "$fixture/files/home/.config/shell", mode = "symlink-each" }
"~/.local/bin" = { source = "$fixture/files/home/.local/bin", mode = "symlink-each", exclude = ["fix-tahoe-focus", "flush-dns", "restart-soundsource", "screen-5.0.1", "try-darwin-aarch64", "try-linux-x86_64"] }
"$sublime_target" = "$fixture/files/home/.config/sublime-text/Packages/User"
$platform_entries
$copy_entry
EOF
}

seed_fixture() {
  local fixture="$1" home="$2" case_name="$3"
  local old="$fixture/mise-dots" new="$fixture/files/home"
  mkdir -p \
    "$old/config/git/hooks" "$old/config/shell" "$old/config/sublime-text/Packages/User" \
    "$old/xdg-bin" "$old/macos/xdg-bin" "$old/linux/xdg-bin" \
    "$new/.config/git/hooks" "$new/.config/shell" "$new/.config/sublime-text/Packages/User" \
    "$new/.local/bin" "$new/Library/Application Support/Rectangle Pro" \
    "$home/.config/git/hooks" "$home/.config/shell" "$home/.local/bin"

  printf 'bash config\n' > "$old/bashrc"
  cp "$old/bashrc" "$new/.bashrc"
  printf 'ignore\n' > "$old/config/git/ignore"
  cp "$old/config/git/ignore" "$new/.config/git/ignore"
  printf 'example\n' > "$old/config/git/local.example"
  cp "$old/config/git/local.example" "$new/.config/git/local.example"
  printf '#!/usr/bin/env bash\n' > "$old/config/git/hooks/pre-commit"
  cp "$old/config/git/hooks/pre-commit" "$new/.config/git/hooks/pre-commit"
  chmod +x "$old/config/git/hooks/pre-commit" "$new/.config/git/hooks/pre-commit"
  printf 'generated\n' > "$new/.config/git/hooks/generated"
  printf 'shell config\n' > "$old/config/shell/all"
  cp "$old/config/shell/all" "$new/.config/shell/all"
  printf 'sublime settings\n' > "$old/config/sublime-text/Packages/User/Preferences.sublime-settings"
  cp "$old/config/sublime-text/Packages/User/Preferences.sublime-settings" \
    "$new/.config/sublime-text/Packages/User/Preferences.sublime-settings"
  printf '#!/usr/bin/env bash\n' > "$old/xdg-bin/common"
  cp "$old/xdg-bin/common" "$new/.local/bin/common"
  printf '#!/usr/bin/env bash\n' > "$old/macos/xdg-bin/fix-tahoe-focus"
  cp "$old/macos/xdg-bin/fix-tahoe-focus" "$new/.local/bin/fix-tahoe-focus"
  printf 'mac try\n' > "$old/macos/xdg-bin/try-darwin-aarch64"
  cp "$old/macos/xdg-bin/try-darwin-aarch64" "$new/.local/bin/try-darwin-aarch64"
  printf 'linux screen\n' > "$old/linux/xdg-bin/screen-5.0.1"
  cp "$old/linux/xdg-bin/screen-5.0.1" "$new/.local/bin/screen-5.0.1"
  printf 'linux try\n' > "$old/linux/xdg-bin/try-linux-x86_64"
  cp "$old/linux/xdg-bin/try-linux-x86_64" "$new/.local/bin/try-linux-x86_64"
  chmod +x "$old/xdg-bin/common" "$new/.local/bin/common" \
    "$old/macos/xdg-bin/fix-tahoe-focus" "$new/.local/bin/fix-tahoe-focus" \
    "$old/macos/xdg-bin/try-darwin-aarch64" "$new/.local/bin/try-darwin-aarch64" \
    "$old/linux/xdg-bin/try-linux-x86_64" "$new/.local/bin/try-linux-x86_64"
  printf '{"copy":true}\n' > "$old/macos/RectangleProConfig.json"
  cp "$old/macos/RectangleProConfig.json" \
    "$new/Library/Application Support/Rectangle Pro/RectangleProConfig.json"

  git -C "$fixture" init -q
  git -C "$fixture" add \
    files/home/.config/git/ignore \
    files/home/.config/git/local.example \
    files/home/.config/git/hooks/pre-commit

  ln -s "$old/bashrc" "$home/.bashrc"
  ln -s "$old/config/git/ignore" "$home/.config/git/ignore"
  ln -s "$old/config/git/local.example" "$home/.config/git/local.example"
  ln -s "$old/config/git/hooks/pre-commit" "$home/.config/git/hooks/pre-commit"
  printf 'private identity\n' > "$home/.config/git/local"
  printf 'generated hook\n' > "$home/.config/git/hooks/post-checkout"
  ln -s "$old/config/shell/all" "$home/.config/shell/all"
  ln -s "$old/xdg-bin/common" "$home/.local/bin/common"
  printf 'unmanaged binary\n' > "$home/.local/bin/unmanaged"

  if [[ "$case_name" == macos ]]; then
    mkdir -p "$home/.config/sublime-text/Packages" \
      "$home/Library/Application Support/Sublime Text 3/Packages" \
      "$home/Library/Application Support/Rectangle Pro"
    ln -s "$old/config/sublime-text/Packages/User" "$home/.config/sublime-text/Packages/User"
    ln -s "$home/.config/sublime-text/Packages/User" \
      "$home/Library/Application Support/Sublime Text 3/Packages/User"
    ln -s "$old/macos/xdg-bin/fix-tahoe-focus" "$home/.local/bin/fix-tahoe-focus"
    ln -s "$old/macos/xdg-bin/try-darwin-aarch64" "$home/.local/bin/try"
    cp "$old/macos/RectangleProConfig.json" \
      "$home/Library/Application Support/Rectangle Pro/RectangleProConfig.json"
  else
    mkdir -p "$home/.config/sublime-text/Packages"
    ln -s "$old/config/sublime-text/Packages/User" "$home/.config/sublime-text/Packages/User"
    ln -s "$old/linux/xdg-bin/screen-5.0.1" "$home/.local/bin/screen"
    ln -s "$old/linux/xdg-bin/try-linux-x86_64" "$home/.local/bin/try"
    rm "$old/bashrc"
  fi
}

run_fixture() {
  local case_name="$1"
  local fixture="$temporary_directory/$case_name/repo" home="$temporary_directory/$case_name/home"
  local new="$fixture/files/home" sublime_target
  mkdir -p "$fixture" "$home"
  seed_fixture "$fixture" "$home" "$case_name"
  write_fixture_config "$fixture" "$case_name"

  HOME="$home" MISE_TRUSTED_CONFIG_PATHS="$fixture" \
    mise -C "$fixture" bootstrap dotfiles apply --yes
  HOME="$home" MISE_TRUSTED_CONFIG_PATHS="$fixture" \
    mise -C "$fixture" bootstrap dotfiles apply --yes
  HOME="$home" MISE_TRUSTED_CONFIG_PATHS="$fixture" \
    mise -C "$fixture" bootstrap dotfiles status --missing

  assert_link "$home/.bashrc" "$new/.bashrc"
  assert_link "$home/.config/git/ignore" "$new/.config/git/ignore"
  assert_link "$home/.config/git/local.example" "$new/.config/git/local.example"
  assert_link "$home/.config/git/hooks/pre-commit" "$new/.config/git/hooks/pre-commit"
  [[ -f "$home/.config/git/local" && ! -L "$home/.config/git/local" ]] ||
    fail "$case_name Git local file was not preserved"
  [[ -f "$home/.config/git/hooks/post-checkout" && ! -L "$home/.config/git/hooks/post-checkout" ]] ||
    fail "$case_name generated Git hook was not preserved"
  [[ ! -e "$home/.config/git/hooks/generated" ]] ||
    fail "$case_name Git manifest deployed an untracked source hook"
  assert_link "$home/.config/shell/all" "$new/.config/shell/all"
  assert_link "$home/.local/bin/common" "$new/.local/bin/common"
  [[ -f "$home/.local/bin/unmanaged" && ! -L "$home/.local/bin/unmanaged" ]] ||
    fail "$case_name unmanaged bin was not preserved"

  if [[ "$case_name" == macos ]]; then
    sublime_target="$home/Library/Application Support/Sublime Text 3/Packages/User"
    assert_link "$home/.local/bin/fix-tahoe-focus" "$new/.local/bin/fix-tahoe-focus"
    assert_link "$home/.local/bin/try" "$new/.local/bin/try-darwin-aarch64"
    [[ ! -e "$home/.local/bin/screen" ]] || fail 'Linux screen leaked into macOS fixture'
    cmp -s "$home/Library/Application Support/Rectangle Pro/RectangleProConfig.json" \
      "$new/Library/Application Support/Rectangle Pro/RectangleProConfig.json" ||
      fail 'Rectangle copy differs in macOS fixture'
  else
    sublime_target="$home/.config/sublime-text/Packages/User"
    assert_link "$home/.local/bin/screen" "$new/.local/bin/screen-5.0.1"
    assert_link "$home/.local/bin/try" "$new/.local/bin/try-linux-x86_64"
    [[ ! -e "$home/.local/bin/fix-tahoe-focus" ]] || fail 'macOS helper leaked into Linux fixture'
  fi
  assert_link "$sublime_target" "$new/.config/sublime-text/Packages/User"
  [[ ! -e "$home/.local/bin/screen-5.0.1" ]] || fail "$case_name exposed the source screen name"
  [[ ! -e "$home/.local/bin/try-darwin-aarch64" ]] || fail "$case_name exposed the macOS source try name"
  [[ ! -e "$home/.local/bin/try-linux-x86_64" ]] || fail "$case_name exposed the Linux source try name"
}

assert_compatibility_tree
run_fixture macos
run_fixture linux

printf 'mise source-layout compatibility tests passed\n'
