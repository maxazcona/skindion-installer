#!/usr/bin/env bash
# bootstrap-harvey.sh â€” Public bootstrap for Skindion Harvey plugin install
# Usage: curl -sSL https://raw.githubusercontent.com/maxazcona/skindion-installer/main/bootstrap-harvey.sh | bash
#
# What this does:
#   1. Verifies (and installs if missing) GitHub CLI via brew (macOS) or apt (Debian/Ubuntu)
#   2. Verifies (and runs) gh auth login if not already authenticated
#   3. Downloads the real install script from the private skindion-agents repo
#      via authenticated gh api â†’ writes to a temp file
#   4. Executes the real install script
#
# Lives in a PUBLIC repo so curl works without auth.

set -euo pipefail

green="\033[1;32m"; yellow="\033[1;33m"; red="\033[1;31m"; cyan="\033[1;36m"; reset="\033[0m"
say()  { printf "${cyan}%s${reset}\n" "$*"; }
ok()   { printf "${green}âœ“${reset} %s\n" "$*"; }
warn() { printf "${yellow}âš  %s${reset}\n" "$*"; }
fail() { printf "${red}âœ— %s${reset}\n" "$*"; exit 1; }

cat <<'BANNER'

  â•­â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â•®
  â”‚   SKINDION HARVEY  âœï¸   â”‚
  â”‚  bootstrapping installer...  â”‚
  â•°â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â•¯

BANNER

# 1. Check / install gh CLI
if ! command -v gh >/dev/null 2>&1; then
    warn "[1/4] GitHub CLI (gh) not found. Attempting install..."
    if command -v brew >/dev/null 2>&1; then
        brew install gh
    elif command -v apt-get >/dev/null 2>&1; then
        # Debian/Ubuntu install per official docs
        type -p curl >/dev/null || sudo apt update && sudo apt install -y curl
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
            && sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
            && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null \
            && sudo apt update \
            && sudo apt install -y gh
    else
        fail "Cannot auto-install gh on this system. Install manually from https://cli.github.com/ and re-run."
    fi
    command -v gh >/dev/null 2>&1 || fail "gh installed but not on PATH. Open a new terminal and re-run the bootstrap."
fi
ok "[1/4] gh available ($(gh --version | head -1))"

# 2. Check / run gh auth login
if ! gh auth status >/dev/null 2>&1; then
    warn "[2/4] Not logged in to GitHub. Opening browser for OAuth..."
    gh auth login --web --git-protocol https --hostname github.com
    gh auth status >/dev/null 2>&1 || fail "gh auth login failed. Run 'gh auth login' manually and re-run."
fi
ok "[2/4] gh authenticated"

# 3. Verify access to the private skindion-agents repo
say "[3/4] Verifying access to maxazcona/skindion-agents..."
if ! gh api repos/maxazcona/skindion-agents >/dev/null 2>&1; then
    fail "Your GitHub account does not have access to maxazcona/skindion-agents (it is private). Ask Max or Mau to add you as a collaborator, then re-run."
fi
ok "[3/4] access verified"

# 4. Download + run the real install script
say "[4/4] Fetching Harvey installer from private repo..."
TMP_INSTALLER="$(mktemp -t harvey-install.XXXXXX.sh)"
if ! gh api -H "Accept: application/vnd.github.raw" repos/maxazcona/skindion-agents/contents/agents/harvey/install/harvey-mac.sh > "$TMP_INSTALLER"; then
    rm -f "$TMP_INSTALLER"
    fail "Failed to download installer from gh api"
fi
chmod +x "$TMP_INSTALLER"
ok "Installer downloaded to $TMP_INSTALLER"

echo
say "Handing off to the Harvey installer..."
echo

bash "$TMP_INSTALLER"
INSTALL_EXIT=$?
rm -f "$TMP_INSTALLER"
exit $INSTALL_EXIT
