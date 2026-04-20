# bootstrap-harvey.ps1 — Public bootstrap for Skindion Harvey plugin install
# Usage: iwr -useb https://raw.githubusercontent.com/maxazcona/skindion-installer/main/bootstrap-harvey.ps1 | iex
#
# What this does:
#   1. Verifies (and installs if missing) GitHub CLI via winget
#   2. Verifies (and runs) gh auth login if not already authenticated
#   3. Downloads the real install script from the private skindion-agents repo
#      via authenticated gh api → writes to a temp .ps1 file (safer than iex)
#   4. Executes the real install script
#
# This file lives in a PUBLIC repo so it's reachable via raw.githubusercontent.com
# without auth. The actual installer + Harvey's skills/hooks/commands stay
# in the private skindion-agents repo.

$ErrorActionPreference = "Stop"

function Write-Color($Text, $Color = "Cyan") {
    Write-Host $Text -ForegroundColor $Color
}

Write-Color ""
Write-Color "  ╭──────────────────────────────╮"
Write-Color "  │   SKINDION HARVEY  ✍️   │" "Green"
Write-Color "  │  bootstrapping installer...  │"
Write-Color "  ╰──────────────────────────────╯"
Write-Color ""

# 1. Check / install gh CLI
$gh = Get-Command gh -ErrorAction SilentlyContinue
if (-not $gh) {
    Write-Color "[1/4] GitHub CLI (gh) not found. Installing via winget..." "Yellow"
    try {
        winget install --id GitHub.cli --silent --accept-source-agreements --accept-package-agreements
        # PATH refresh: winget adds to PATH but current session needs reload
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        $gh = Get-Command gh -ErrorAction SilentlyContinue
        if (-not $gh) {
            Write-Color "✗ gh installed but not on PATH. Close this PowerShell window and re-run the bootstrap one-liner." "Red"
            exit 1
        }
    }
    catch {
        Write-Color "✗ winget install failed. Install gh manually from https://cli.github.com/ and re-run." "Red"
        exit 1
    }
    Write-Color "✓ gh installed" "Green"
} else {
    Write-Color "[1/4] ✓ gh already installed ($($gh.Version))" "Green"
}

# 2. Check / run gh auth login
$authStatus = & gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Color "[2/4] Not logged in to GitHub. Opening browser for OAuth..." "Yellow"
    & gh auth login --web --git-protocol https --hostname github.com
    if ($LASTEXITCODE -ne 0) {
        Write-Color "✗ gh auth login failed. Run 'gh auth login' manually and re-run the bootstrap." "Red"
        exit 1
    }
    Write-Color "✓ gh authenticated" "Green"
} else {
    $accountLine = $authStatus | Select-String "Active account: true" -Context 1, 0
    Write-Color "[2/4] ✓ gh already authenticated" "Green"
}

# 3. Verify access to the private skindion-agents repo
Write-Color "[3/4] Verifying access to maxazcona/skindion-agents..." "Yellow"
& gh api repos/maxazcona/skindion-agents 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Color "✗ Your GitHub account does not have access to maxazcona/skindion-agents (it is private)." "Red"
    Write-Color "  Ask Max or Mau to add you as a collaborator. Then re-run this bootstrap." "Red"
    exit 1
}
Write-Color "✓ Access verified" "Green"

# 4. Download + run the real install script
Write-Color "[4/4] Fetching Harvey installer from private repo..." "Yellow"
$tempInstaller = Join-Path $env:TEMP "harvey-install-$(Get-Random).ps1"
try {
    $scriptContent = & gh api -H "Accept: application/vnd.github.raw" "repos/maxazcona/skindion-agents/contents/agents/harvey/install/harvey-win.ps1"
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($scriptContent)) {
        throw "gh api returned empty content"
    }
    # Write with UTF-8 BOM so PowerShell handles emoji + Spanish chars correctly
    $utf8Bom = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllText($tempInstaller, $scriptContent, $utf8Bom)
    Write-Color "✓ Installer downloaded to $tempInstaller" "Green"
}
catch {
    Write-Color "✗ Failed to download installer: $($_.Exception.Message)" "Red"
    exit 1
}

Write-Color ""
Write-Color "Handing off to the Harvey installer..." "Cyan"
Write-Color ""

# Execute the real installer as a script (not via iex, which fails on multi-line functions)
& $tempInstaller

# Clean up
Remove-Item $tempInstaller -ErrorAction SilentlyContinue
