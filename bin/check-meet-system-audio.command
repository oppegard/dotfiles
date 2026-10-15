#!/bin/bash
# Inspect live Google Meet selections without selecting any audio device.
set -u

case "${1-}" in
-h | --help)
	cat <<'HELP'
Usage: check-meet-system-audio.command

Check the one open Google Meet tab or Chrome PWA window.
Open Google Meet > Settings > Audio first, or leave Meet on its home page.
English Google Meet UI is required.

Exit 0: microphone AND speaker use System default.
Exit 1: at least one selected device is explicit rather than System default.
Exit 2: inspection failed or the Meet tab is ambiguous.

Requires macOS Automation access to Google Chrome and Chrome's
View > Developer > Allow JavaScript from Apple Events setting.
This command does not enable permissions or change audio devices.
HELP
	exit 0
	;;
'') ;;
*)
	printf '\033[31mERROR\033[0m Unknown argument: %s. Use --help.\n' "$1" >&2
	exit 2
	;;
esac
if [ "$#" -ne 0 ]; then
	printf '\033[31mERROR\033[0m This command accepts no arguments. Use --help.\n' >&2
	exit 2
fi

result=$(
	/usr/bin/osascript -l JavaScript <<'JXA' 2>&1
function run() {
  var chrome = Application('/Applications/Google Chrome.app');
  var tab, openedSettings = false, openKind = null, errors = [], selections = [];
  function clean(value) { return String(value).replace(/[\x00-\x1f\x7f]+/g, ' ').replace(/\s+/g, ' ').trim(); }
  function page(action, kind) {
    var source = '(' + dom.toString() + ')(' + JSON.stringify(action) + ',' + JSON.stringify(kind || '') + ')';
    try {
      return JSON.parse(tab.execute({javascript: source}));
    } catch (e) {
      throw new Error('Cannot inspect Chrome. Allow Automation access to Google Chrome for the launching app, and enable Chrome > View > Developer > Allow JavaScript from Apple Events. Then run again. Details: ' + clean(e.message || e));
    }
  }
  function dom(action, kind) {
    function text(value) { return String(value || '').replace(/[\x00-\x1f\x7f]+/g, ' ').replace(/\s+/g, ' ').trim(); }
    function visible(el) { return !!(el.getClientRects().length && getComputedStyle(el).visibility !== 'hidden'); }
    function all(selector, root) { return Array.from((root || document).querySelectorAll(selector)).filter(visible); }
    function name(el) {
      var refs = (el.getAttribute('aria-labelledby') || '').split(/\s+/).filter(Boolean);
      return text(el.getAttribute('aria-label') || refs.map(function(id) { var e = document.getElementById(id); return e ? e.textContent : ''; }).join(' ') || el.textContent);
    }
    function one(items, description) { if (items.length !== 1) throw new Error('Expected one ' + description + '; found ' + items.length + '. Open Meet > Settings > Audio and close any other menus.'); return items[0]; }
    function settings() { return all('[role="dialog"]').filter(function(el) { return name(el) === 'Settings'; }); }
    function dialog() { return one(settings(), 'Settings dialog'); }
    function opener() { return one(all('button, [role="button"]', dialog()).filter(function(el) { return name(el).indexOf(kind === 'microphone' ? 'Microphone:' : 'Speaker:') === 0 && el.getAttribute('aria-haspopup') === 'menu'; }), kind + ' dropdown'); }
    function menu() { return all('[role="menu"]').filter(function(el) { return name(el) === 'Device selection for the ' + kind; }); }
    try {
      if (location.origin !== 'https://meet.google.com') throw new Error('The target tab is no longer Google Meet.');
      if (action === 'prepare') {
        if (all('[role="menu"]').length) throw new Error('Close the open Meet menu and run again.');
        if (settings().length === 1) return JSON.stringify({ready: true});
        if (all('[role="dialog"]').length || !/^\/(home)?\/?$/.test(location.pathname)) throw new Error('Open Meet > Settings > Audio and run again.');
        one(all('button, [role="button"]').filter(function(el) { return name(el) === 'Settings'; }), 'home Settings button').click();
        return JSON.stringify({opened: true});
      }
      if (action === 'audio') {
        if (!settings().length) return JSON.stringify({pending: true});
        var audio = one(all('[role="tab"]', dialog()).filter(function(el) { return name(el) === 'Audio'; }), 'Audio tab');
        if (audio.getAttribute('aria-selected') !== 'true') audio.click();
        return JSON.stringify({pending: all('button, [role="button"]', dialog()).filter(function(el) { return /^(Microphone|Speaker):/.test(name(el)); }).length !== 2});
      }
      if (action === 'open') {
        var button = opener();
        if (all('[role="menu"]').length) throw new Error('Close the open Meet menu and run again.');
        button.click();
        return JSON.stringify({opened: true});
      }
      if (action === 'read') {
        if (!menu().length) return JSON.stringify({pending: true});
        var selected = all('[role="menuitemradio"]', one(menu(), kind + ' menu')).filter(function(el) { return el.getAttribute('aria-checked') === 'true'; });
        var item = one(selected, 'selected ' + kind + ' item');
        var id = item.getAttribute('data-device-id');
        if (!id || !text(id)) throw new Error('Selected ' + kind + ' has no device ID.');
        var label = name(item).replace(/^check\s*/, '');
        if (!label) throw new Error('Selected ' + kind + ' has no readable label.');
        return JSON.stringify({kind: kind, label: label, followsSystem: id === 'default'});
      }
      if (action === 'close-menu') {
        if (menu().length) opener().click();
        return JSON.stringify({clicked: true});
      }
      if (action === 'menu-closed') return JSON.stringify({pending: menu().length !== 0});
      if (action === 'close-settings') {
        one(all('button, [role="button"]', dialog()).filter(function(el) { return name(el) === 'Close dialog'; }), 'Settings Close button').click();
        return JSON.stringify({clicked: true});
      }
      if (action === 'settings-closed') return JSON.stringify({pending: settings().length !== 0});
      throw new Error('Unknown inspection action.');
    } catch (e) { return JSON.stringify({error: text(e.message || e)}); }
  }
  function checked(action, kind) {
    var value = page(action, kind);
    if (!value || value.error) throw new Error(value && value.error || 'Chrome returned no inspection data.');
    return value;
  }
  function poll(action, kind) {
    for (var i = 0; i < 25; i++) {
      var value = checked(action, kind);
      if (!value.pending) return value;
      delay(0.1);
    }
    throw new Error('Timed out reading Meet ' + (kind || 'Settings') + '. Open Settings > Audio and run again.');
  }
  try {
    if (!chrome.running()) throw new Error('Google Chrome is not running. Open the Google Meet PWA or a Meet tab and run again.');
    var matches = [];
    chrome.windows().forEach(function(window) {
      window.tabs().forEach(function(candidate) {
        if (/^https:\/\/meet\.google\.com\//.test(candidate.url())) matches.push(candidate);
      });
    });
    if (matches.length !== 1) throw new Error('Expected exactly one open Google Meet tab or PWA window; found ' + matches.length + '. Keep one Meet tab open and run again.');
    tab = matches[0];
    openedSettings = !!checked('prepare').opened;
    poll('audio');
    ['microphone', 'speaker'].forEach(function(kind) {
      try {
        checked('open', kind);
        openKind = kind;
        selections.push(poll('read', kind));
      } catch (e) { errors.push(clean(e.message || e)); }
      finally {
        if (openKind) {
          try { checked('close-menu', openKind); poll('menu-closed', openKind); }
          catch (e) { errors.push(clean(e.message || e)); }
          openKind = null;
        }
      }
    });
  } catch (e) {
    var message = clean(e.message || e);
    if (/not authorized|not permitted|privilege|-1743/i.test(message)) message = 'Allow macOS Automation access to Google Chrome for the launching app, then run again. Details: ' + message;
    errors.push(message);
  } finally {
    if (openedSettings) {
      try { checked('close-settings'); poll('settings-closed'); }
      catch (e) { errors.push(clean(e.message || e)); }
    }
  }
  if (errors.length) return '2\n\x1b[31mERROR\x1b[0m ' + errors.join('\n\x1b[31mERROR\x1b[0m ');
  if (selections.length !== 2) return '2\n\x1b[31mERROR\x1b[0m Incomplete audio inspection.';
  var failed = selections.some(function(s) { return !s.followsSystem; });
  return (failed ? '1' : '0') + '\n' + selections.map(function(s) {
    return (s.followsSystem ? '\x1b[32mPASS\x1b[0m ' : '\x1b[31mFAIL\x1b[0m ') + s.kind + ': ' + s.label + ' [' + (s.followsSystem ? 'System default' : 'explicit device') + ']';
  }).join('\n');
}
JXA
)
status=$?
if [ "$status" -ne 0 ]; then
	printf '\033[31mERROR\033[0m Could not run the Google Meet check: %s\n' "$result" >&2
	exit 2
fi
case "$result" in
0$'\n'*)
	printf '%s\n' "${result#*$'\n'}"
	exit 0
	;;
1$'\n'*)
	printf '%s\n' "${result#*$'\n'}"
	exit 1
	;;
2$'\n'*)
	printf '%s\n' "${result#*$'\n'}" >&2
	exit 2
	;;
*)
	printf '\033[31mERROR\033[0m Unexpected inspection result: %s\n' "$result" >&2
	exit 2
	;;
esac
