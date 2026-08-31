#!/usr/bin/env bash
#
# fxa-dev-launcher.sh — launch Firefox against an FxA environment.
#
# A dependency-free port of `yarn firefox` (packages/fxa-dev-launcher). No node,
# no yarn, no repo checkout required: copy this one file anywhere and run it.
#
#   ./fxa-dev-launcher.sh stage        # Nightly pointed at stage
#   ./fxa-dev-launcher.sh --help
#
# Keep the pref list in sync with ../profile.mjs.

set -eu

SCRIPT_NAME="$(basename "$0")"

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [env] [options] [-- firefox args...]

Launches Firefox with a dedicated profile configured to talk to an FxA
environment. Runs alongside your everyday Firefox; your normal profile,
bookmarks and logins are untouched.

Environments:
  local          localhost (default)
  stage          accounts.stage.mozaws.net
  prod           accounts.firefox.com
  latest         latest.dev.lcip.org
  stable         stable.dev.lcip.org
  start-remote   local content server, fxaci auth
  <name>         anything else is treated as <name>.dev.lcip.org

Options:
  -b, --bin PATH     Firefox binary (default: Nightly, else Firefox)
  -c, --context CTX  fxa-content-server context param
                     (default: oauth_webchannel_v1; use fx_desktop_v3 for the
                     pre-ESR-140 Desktop flow)
  -p, --profile DIR  profile directory (default: ~/.fxa-dev-launcher/<env>)
  -r, --reset        delete the profile first: signed out, clean state
  -d, --debugger     open the Browser Toolbox on start (default)
  -D, --no-debugger  do not open the Browser Toolbox
      --no-e10s      disable multi-process (e10s)
  -n, --dry-run      print the resolved config and profile, launch nothing
  -h, --help         show this message

Environment variables FXA_ENV, FIREFOX_BIN, FXA_DESKTOP_CONTEXT,
FIREFOX_DEBUGGER and DISABLE_E10S are honored, so the invocations documented
for \`yarn firefox\` work here too. Flags win over env vars.
EOF
}

die() {
  echo "$SCRIPT_NAME: $*" >&2
  exit 1
}

# --- defaults, overridable by env then flags -------------------------------

ENV_NAME="${FXA_ENV:-local}"
env_from_flag=""
FIREFOX_BIN="${FIREFOX_BIN:-}"
FXA_DESKTOP_CONTEXT="${FXA_DESKTOP_CONTEXT:-oauth_webchannel_v1}"
PROFILE_DIR=""
RESET=false
DRY_RUN=false

# `yarn firefox` sets FIREFOX_DEBUGGER=true, so match that default.
DEBUGGER=true
case "${FIREFOX_DEBUGGER:-true}" in
  false | 0 | '') DEBUGGER=false ;;
esac

DISABLE_E10S_FLAG=false
if [ "${DISABLE_E10S:-}" = "true" ]; then
  DISABLE_E10S_FLAG=true
fi

# --- arguments ------------------------------------------------------------

FIREFOX_EXTRA_ARGS=""

while [ $# -gt 0 ]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    -b | --bin)
      [ $# -ge 2 ] || die "$1 requires a path"
      FIREFOX_BIN="$2"
      shift 2
      ;;
    -c | --context)
      [ $# -ge 2 ] || die "$1 requires a value"
      FXA_DESKTOP_CONTEXT="$2"
      shift 2
      ;;
    -p | --profile)
      [ $# -ge 2 ] || die "$1 requires a path"
      PROFILE_DIR="$2"
      shift 2
      ;;
    -r | --reset)
      RESET=true
      shift
      ;;
    -d | --debugger)
      DEBUGGER=true
      shift
      ;;
    -D | --no-debugger)
      DEBUGGER=false
      shift
      ;;
    --no-e10s)
      DISABLE_E10S_FLAG=true
      shift
      ;;
    -n | --dry-run)
      DRY_RUN=true
      shift
      ;;
    --)
      shift
      FIREFOX_EXTRA_ARGS="$*"
      break
      ;;
    -*)
      die "unknown option: $1 (try --help)"
      ;;
    *)
      [ -z "$env_from_flag" ] || die "more than one environment given: $env_from_flag, $1"
      env_from_flag="$1"
      ENV_NAME="$1"
      shift
      ;;
  esac
done

# --- environment config ---------------------------------------------------
# Mirrors CONFIGS in ../profile.mjs.

case "$ENV_NAME" in
  local)
    FXA_AUTH="http://localhost:9000/v1"
    FXA_CONTENT="http://localhost:3030/"
    FXA_TOKEN="http://localhost:8000/1.0/sync/1.5"
    FXA_OAUTH="http://localhost:9000/v1"
    FXA_PROFILE="http://localhost:1111/v1"
    ;;
  latest)
    FXA_AUTH="https://latest.dev.lcip.org/auth/v1"
    FXA_CONTENT="https://latest.dev.lcip.org/"
    FXA_TOKEN="https://latest.dev.lcip.org/syncserver/token/1.0/sync/1.5"
    FXA_OAUTH="https://oauth-latest.dev.lcip.org/v1"
    FXA_PROFILE="https://latest.dev.lcip.org/profile/v1"
    ;;
  start-remote)
    FXA_AUTH="https://fxaci.dev.lcip.org/auth/v1"
    FXA_CONTENT="http://localhost:3030/"
    FXA_TOKEN="https://fxaci.dev.lcip.org/syncserver/token/1.0/sync/1.5"
    FXA_OAUTH="https://oauth-fxaci.dev.lcip.org/v1"
    FXA_PROFILE="https://fxaci.dev.lcip.org/profile/v1"
    ;;
  stable)
    FXA_AUTH="https://stable.dev.lcip.org/auth/v1"
    FXA_CONTENT="https://stable.dev.lcip.org/"
    FXA_TOKEN="https://stable.dev.lcip.org/syncserver/token/1.0/sync/1.5"
    FXA_OAUTH="https://oauth-stable.dev.lcip.org/v1"
    FXA_PROFILE="https://stable.dev.lcip.org/profile/v1"
    ;;
  stage)
    FXA_AUTH="https://api-accounts.stage.mozaws.net/v1"
    FXA_CONTENT="https://accounts.stage.mozaws.net/"
    FXA_TOKEN="https://token.stage.mozaws.net/1.0/sync/1.5"
    FXA_OAUTH="https://oauth.stage.mozaws.net/v1"
    FXA_PROFILE="https://profile.stage.mozaws.net/v1"
    ;;
  prod)
    FXA_AUTH="https://api.accounts.firefox.com/v1"
    FXA_CONTENT="https://accounts.firefox.com/"
    FXA_TOKEN="https://token.services.mozilla.com/1.0/sync/1.5"
    FXA_OAUTH="https://oauth.accounts.firefox.com/v1"
    FXA_PROFILE="https://profile.accounts.firefox.com/v1"
    ;;
  *)
    # Unknown env: assume it's an fxa-dev box.
    host="https://$ENV_NAME.dev.lcip.org/"
    FXA_AUTH="${host}auth/v1"
    FXA_CONTENT="$host"
    FXA_TOKEN="${host}syncserver/token/1.0/sync/1.5"
    FXA_OAUTH="https://oauth-$ENV_NAME.dev.lcip.org/v1"
    FXA_PROFILE="${host}profile/v1"
    ;;
esac

# --- Firefox binary -------------------------------------------------------

resolve_bin() {
  # An .app bundle is fine too; dig out the executable.
  case "$1" in
    *.app | *.app/)
      app="${1%/}"
      for candidate in "$app/Contents/MacOS/firefox" "$app/Contents/MacOS/firefox-bin"; do
        if [ -x "$candidate" ]; then
          echo "$candidate"
          return 0
        fi
      done
      return 1
      ;;
    *)
      [ -x "$1" ] || return 1
      echo "$1"
      ;;
  esac
}

if [ -n "$FIREFOX_BIN" ]; then
  # Assign via a temp so the failure message can still name what was passed.
  resolved="$(resolve_bin "$FIREFOX_BIN")" ||
    die "not an executable Firefox binary: $FIREFOX_BIN"
  FIREFOX_BIN="$resolved"
else
  # Nightly first: it is what we ask people to test against.
  for app in \
    "$HOME/Applications/Firefox Nightly.app" \
    "/Applications/Firefox Nightly.app" \
    "$HOME/Applications/Firefox Developer Edition.app" \
    "/Applications/Firefox Developer Edition.app" \
    "$HOME/Applications/Firefox.app" \
    "/Applications/Firefox.app"; do
    if FIREFOX_BIN="$(resolve_bin "$app" 2>/dev/null)"; then
      break
    fi
    FIREFOX_BIN=""
  done

  if [ -z "$FIREFOX_BIN" ]; then
    FIREFOX_BIN="$(command -v firefox 2>/dev/null)" || FIREFOX_BIN=""
  fi

  [ -n "$FIREFOX_BIN" ] || die "no Firefox found. Install Firefox Nightly
  (https://www.mozilla.org/firefox/channel/desktop/#nightly) or pass --bin PATH."
fi

IS_NIGHTLY=false
case "$FIREFOX_BIN" in
  *[Nn]ightly*) IS_NIGHTLY=true ;;
esac

# --- profile --------------------------------------------------------------

if [ -z "$PROFILE_DIR" ]; then
  PROFILE_DIR="$HOME/.fxa-dev-launcher/$ENV_NAME"
fi

case "$PROFILE_DIR" in
  /*) ;;
  *) PROFILE_DIR="$PWD/$PROFILE_DIR" ;;
esac

if [ "$RESET" = true ] && [ -d "$PROFILE_DIR" ]; then
  # Only ever remove a directory that looks like one of ours.
  [ -f "$PROFILE_DIR/user.js" ] || [ -f "$PROFILE_DIR/prefs.js" ] ||
    die "refusing to reset $PROFILE_DIR: it is not a Firefox profile"
  echo "Resetting profile: $PROFILE_DIR"
  rm -rf "$PROFILE_DIR"
fi

# --- report ---------------------------------------------------------------

if [ -t 1 ]; then
  Y="$(printf '\033[33m')"
  R="$(printf '\033[0m')"
else
  Y=""
  R=""
fi

E10S=true
[ "$DISABLE_E10S_FLAG" = true ] && E10S=false

printf '%s' "$Y"
cat <<EOF
FXA_ENV: $ENV_NAME
  auth:    $FXA_AUTH
  content: $FXA_CONTENT
  oauth:   $FXA_OAUTH
  profile: $FXA_PROFILE
  token:   $FXA_TOKEN
Firefox binary: $FIREFOX_BIN
Firefox profile: $PROFILE_DIR
FXA_DESKTOP_CONTEXT: $FXA_DESKTOP_CONTEXT
E10S: $E10S
Browser Toolbox: $DEBUGGER
EOF
printf '%s' "$R"

if [ "$DRY_RUN" = true ]; then
  exit 0
fi

# --- write prefs ----------------------------------------------------------
# user.js is applied on every start, so rewriting it lets an env or context
# change take effect on a profile that is already signed in.

mkdir -p "$PROFILE_DIR"

OAUTH_ENABLED=false
if [ "$FXA_DESKTOP_CONTEXT" = "oauth_webchannel_v1" ]; then
  OAUTH_ENABLED=true
fi

{
  echo "// Generated by $SCRIPT_NAME — do not edit, it is rewritten on every start."

  if [ "$IS_NIGHTLY" = true ]; then
    echo 'user_pref("browser.smartwindow.enabled", true);'
  fi

  cat <<'EOF'
// enable debugger and toolbox
user_pref("devtools.chrome.enabled", true);
user_pref("devtools.debugger.remote-enabled", true);
user_pref("devtools.debugger.prompt-connection", false);
// disable about:config warning
user_pref("general.warnOnAboutConfig", false);
// disable signed extensions
// the WebDriver extension will not work in Nightly because signed extensions are forced
user_pref("xpinstall.signatures.required", false);
user_pref("xpinstall.whitelist.required", false);
user_pref("services.sync.prefs.sync.xpinstall.whitelist.required", false);
user_pref("extensions.checkCompatibility.nightly", false);
// enable pocket
user_pref("browser.pocket.enabled", true);
// identity logs
user_pref("identity.fxaccounts.log.appender.dump", "Debug");
user_pref("identity.fxaccounts.loglevel", "Debug");
user_pref("services.sync.log.appender.file.logOnSuccess", true);
user_pref("services.sync.log.appender.console", "Debug");
user_pref("browser.uitour.testingOrigins", "http://localhost:8001,http://localhost:8000,https://www.mozilla.org,https://www.allizom.org,https://www-demo5.allizom.org,https://www-dev.allizom.org");
user_pref("browser.uitour.requireSecure", false);
user_pref("services.sync.log.appender.dump", "Debug");
user_pref("identity.fxaccounts.allowHttp", true);
// disable auto update
user_pref("app.update.auto", false);
user_pref("app.update.enabled", false);
user_pref("app.update.silent", false);
user_pref("app.update.staging.enabled", false);
user_pref("browser.tabs.firefox-view", true);
// disable password auto-fill; we typically don't need to test this daily.
user_pref("signon.rememberSignons", false);
EOF

  cat <<EOF
user_pref("identity.fxaccounts.auth.uri", "$FXA_AUTH");
user_pref("identity.fxaccounts.remote.root", "$FXA_CONTENT");
user_pref("identity.fxaccounts.remote.force_auth.uri", "${FXA_CONTENT}force_auth?service=sync&context=$FXA_DESKTOP_CONTEXT");
user_pref("identity.fxaccounts.remote.signin.uri", "${FXA_CONTENT}signin?service=sync&context=$FXA_DESKTOP_CONTEXT");
user_pref("identity.fxaccounts.remote.signup.uri", "${FXA_CONTENT}signup?service=sync&context=$FXA_DESKTOP_CONTEXT");
user_pref("identity.fxaccounts.remote.webchannel.uri", "$FXA_CONTENT");
user_pref("identity.fxaccounts.remote.oauth.uri", "$FXA_OAUTH");
user_pref("identity.fxaccounts.remote.profile.uri", "$FXA_PROFILE");
user_pref("identity.fxaccounts.settings.uri", "${FXA_CONTENT}settings?service=sync&context=$FXA_DESKTOP_CONTEXT");
// for some reason there are 2 settings for the token server
user_pref("identity.sync.tokenserver.uri", "$FXA_TOKEN");
user_pref("services.sync.tokenServerURI", "$FXA_TOKEN");
user_pref("identity.fxaccounts.contextParam", "$FXA_DESKTOP_CONTEXT");
user_pref("browser.newtabpage.activity-stream.fxaccounts.endpoint", "$FXA_CONTENT");
// allow webchannel url, strips slash from content-server origin.
user_pref("webchannel.allowObject.urlWhitelist", "${FXA_CONTENT%/}");
// TODO in FXA-11026, see if we still need the other prefs since we only need
// to use the autoconfig to get everything else set. See: bug 1942925.
user_pref("identity.fxaccounts.autoconfig.uri", "$FXA_CONTENT");
user_pref("identity.fxaccounts.oauth.enabled", $OAUTH_ENABLED);
EOF

  if [ "$DISABLE_E10S_FLAG" = true ]; then
    cat <<'EOF'
// disable e10s
user_pref("browser.tabs.remote.autostart", false);
user_pref("browser.tabs.remote.autostart.1", false);
user_pref("browser.tabs.remote.autostart.2", false);
EOF
  fi
} >"$PROFILE_DIR/user.js"

# --- launch ---------------------------------------------------------------
# --no-remote plus --new-instance so this runs next to an already-open Firefox.

set -- --profile "$PROFILE_DIR" --no-remote --new-instance
[ "$DEBUGGER" = true ] && set -- "$@" -jsdebugger
# shellcheck disable=SC2086 # deliberate word splitting of the pass-through args
[ -n "$FIREFOX_EXTRA_ARGS" ] && set -- "$@" $FIREFOX_EXTRA_ARGS

exec "$FIREFOX_BIN" "$@"
