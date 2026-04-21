#!/usr/bin/env bash
# bootstrap-harvey.sh - Public bootstrap for Skindion Harvey plugin
# Usage: curl -sSL https://raw.githubusercontent.com/maxazcona/skindion-installer/main/bootstrap-harvey.sh | bash
#
# Designed for virgin Macs with NO developer tools installed.
# Pure ASCII output (no Unicode). TTY redirects for sudo + brew + gh auth.

set -eu

G="\033[1;32m"; Y="\033[1;33m"; R="\033[1;31m"; C="\033[1;36m"; Z="\033[0m"
say()  { printf "%b%s%b\n" "$C" "$*" "$Z"; }
ok()   { printf "%b[OK]%b   %s\n" "$G" "$Z" "$*"; }
warn() { printf "%b[WARN]%b %s\n" "$Y" "$Z" "$*"; }
fail() { printf "%b[FAIL]%b %s\n" "$R" "$Z" "$*"; exit 1; }

cat <<'BANNER'

  +----------------------------------------------------+
  |                                                    |
  |          S K I N D I O N    A G E N T S            |
  |                                                    |
  |          H A R V E Y    -    copywriter            |
  |          bootstrapping installer...                |
  |                                                    |
  +----------------------------------------------------+

BANNER

OS_KIND="$(uname -s)"

# Under 'curl | bash' stdin is the pipe. We need /dev/tty for sudo + brew + gh.
TTY_DEV=""
if [ -r /dev/tty ] && [ -w /dev/tty ]; then
    TTY_DEV="/dev/tty"
fi

if [ "$OS_KIND" = "Darwin" ]; then

    # 1. Xcode Command Line Tools (needed for git, cc, brew)
    if ! xcode-select -p >/dev/null 2>&1; then
        warn "[1/5] Xcode Command Line Tools missing - triggering GUI install..."
        xcode-select --install 2>/dev/null || true
        say "       A macOS dialog should have appeared. Click 'Install', accept the EULA, wait 5-10 min."
        say "       When it says 'Software was installed', return here and press Enter."
        if [ -n "$TTY_DEV" ]; then
            read -r _ <"$TTY_DEV"
        fi
        if ! xcode-select -p >/dev/null 2>&1; then
            fail "Xcode CLT still missing. Install manually then re-run bootstrap."
        fi
        ok "Xcode CLT installed"
    else
        ok "[1/5] Xcode CLT present"
    fi

    # 2. Homebrew
    if ! command -v brew >/dev/null 2>&1; then
        warn "[2/5] Homebrew not installed - installing (needs your Mac password)..."
        if [ -n "$TTY_DEV" ]; then
            sudo -v <"$TTY_DEV" || fail "Could not get sudo access."
            ( while true; do sudo -n true; sleep 50; done ) &
            SUDO_KEEPALIVE_PID=$!
            trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null || true' EXIT
        fi
        BREW_INSTALLER="$(mktemp -t brew-install.XXXXXX.sh)"
        curl -fsSL "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" -o "$BREW_INSTALLER" \
            || fail "Could not download Homebrew installer."
        export NONINTERACTIVE=1
        if [ -n "$TTY_DEV" ]; then
            bash "$BREW_INSTALLER" <"$TTY_DEV" || fail "Homebrew install failed."
        else
            bash "$BREW_INSTALLER" || fail "Homebrew install failed."
        fi
        rm -f "$BREW_INSTALLER"
        if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
        if [ -x /usr/local/bin/brew ];   then eval "$(/usr/local/bin/brew shellenv)"; fi
        command -v brew >/dev/null 2>&1 || fail "Homebrew installed but not on PATH. Open a new terminal + re-run."
        ok "Homebrew installed"
    else
        ok "[2/5] Homebrew present"
    fi

    # 3. gh CLI
    if ! command -v gh >/dev/null 2>&1; then
        warn "[3/5] GitHub CLI missing - installing via brew..."
        brew install gh || fail "brew install gh failed."
        ok "gh installed"
    else
        ok "[3/5] gh present"
    fi

elif command -v apt-get >/dev/null 2>&1; then
    if ! command -v gh >/dev/null 2>&1; then
        say "[1-3/5] Installing gh on Debian/Ubuntu..."
        type -p curl >/dev/null || sudo apt update && sudo apt install -y curl
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
            && sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
            && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null \
            && sudo apt update && sudo apt install -y gh
    fi
    ok "[1-3/5] Linux prereqs OK"
else
    fail "Unsupported OS: $OS_KIND"
fi

# 4. gh auth
if ! gh auth status >/dev/null 2>&1; then
    warn "[4/5] Not logged in to GitHub - opening browser..."
    say "       Click 'Authorize' in the browser tab, return here."
    if [ -n "$TTY_DEV" ]; then
        gh auth login --web --git-protocol https --hostname github.com <"$TTY_DEV"
    else
        gh auth login --web --git-protocol https --hostname github.com
    fi
    gh auth status >/dev/null 2>&1 || fail "gh auth login did not complete."
    ok "gh authenticated"
else
    ok "[4/5] gh already authenticated"
fi

# 5. Repo access + download installer
say "[5/5] Verifying access to maxazcona/skindion-agents..."
gh api repos/maxazcona/skindion-agents >/dev/null 2>&1 \
    || fail "Your GitHub account is not a collaborator on maxazcona/skindion-agents. Ask Max to invite you, accept the email, re-run."
ok "access verified"

say "Downloading the Harvey installer..."
TMP_INSTALLER="$(mktemp -t harvey-install.XXXXXX.sh)"
gh api -H "Accept: application/vnd.github.raw" repos/maxazcona/skindion-agents/contents/agents/harvey/install/harvey-mac.sh > "$TMP_INSTALLER" \
    || fail "Failed to download installer."
SIZE=$(wc -c < "$TMP_INSTALLER" | tr -d ' ')
[ "$SIZE" -gt 1000 ] || fail "Installer too small ($SIZE bytes)."
chmod +x "$TMP_INSTALLER"
ok "installer downloaded ($SIZE bytes)"

cat <<'HANDOFF'

  +----------------------------------------------------+
  |  Bootstrap done. Handing off to Harvey installer.  |
  |  Next part will ask for your MCP_WIKI_TOKEN.       |
  |  (Mau sent it in the invite email - have it ready.)|
  +----------------------------------------------------+

HANDOFF

if [ -n "$TTY_DEV" ]; then
    bash "$TMP_INSTALLER" <"$TTY_DEV"
else
    bash "$TMP_INSTALLER"
fi
INSTALL_EXIT=$?
rm -f "$TMP_INSTALLER"
exit $INSTALL_EXIT