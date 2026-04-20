# bootstrap-harvey.ps1 - Public bootstrap for Skindion Harvey plugin install
# Usage: iwr -useb https://raw.githubusercontent.com/maxazcona/skindion-installer/main/bootstrap-harvey.ps1 | iex
#
# What this does:
#   1. Verifies (and installs if missing) GitHub CLI via winget
#   2. Verifies (and runs) gh auth login if not already authenticated
#   3. Downloads the real install script from the private skindion-agents repo
#      via authenticated gh api -> writes to a temp .ps1 file
#   4. Executes the real install script as a child process

$ErrorActionPreference = "Stop"

function Say($Text, $Color = "Cyan") { Write-Host $Text -ForegroundColor $Color }

Say ""
Say "================================================"
Say "  SKINDION HARVEY  -  bootstrapping installer  " "Green"
Say "================================================"
Say ""

# 1. Check / install gh CLI
$gh = Get-Command gh -ErrorAction SilentlyContinue
if (-not $gh) {
    Say "[1/4] GitHub CLI (gh) not found. Installing via winget..." "Yellow"
    try {
        winget install --id GitHub.cli --silent --accept-source-agreements --accept-package-agreements | Out-Null
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        $gh = Get-Command gh -ErrorAction SilentlyContinue
        if (-not $gh) {
            Say "[FAIL] gh installed but not on PATH. Close this PowerShell window and re-run the bootstrap one-liner." "Red"
            exit 1
        }
    } catch {
        Say "[FAIL] winget install failed. Install gh manually from https://cli.github.com/ and re-run." "Red"
        exit 1
    }
    Say "[OK] gh installed" "Green"
} else {
    Say "[1/4] [OK] gh already installed" "Green"
}

# 2. Check / run gh auth login
& gh auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Say "[2/4] Not logged in to GitHub. Opening browser for OAuth..." "Yellow"
    & gh auth login --web --git-protocol https --hostname github.com
    if ($LASTEXITCODE -ne 0) {
        Say "[FAIL] gh auth login failed. Run 'gh auth login' manually and re-run the bootstrap." "Red"
        exit 1
    }
    Say "[OK] gh authenticated" "Green"
} else {
    Say "[2/4] [OK] gh already authenticated" "Green"
}

# 3. Verify access to the private skindion-agents repo
Say "[3/4] Verifying access to maxazcona/skindion-agents..." "Yellow"
& gh api repos/maxazcona/skindion-agents 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Say "[FAIL] Your GitHub account does not have access to maxazcona/skindion-agents (it is private)." "Red"
    Say "       Ask Max or Mau to add you as a collaborator. Then re-run this bootstrap." "Red"
    exit 1
}
Say "[OK] Access verified" "Green"

# 4. Download + run the real install script
Say "[4/4] Fetching Harvey installer from private repo..." "Yellow"
$tempInstaller = Join-Path $env:TEMP "harvey-install-$(Get-Random).ps1"
try {
    # gh api emits the raw bytes; pipe to Out-File which handles array-to-text correctly
    & gh api -H "Accept: application/vnd.github.raw" "repos/maxazcona/skindion-agents/contents/agents/harvey/install/harvey-win.ps1" | Out-File -FilePath $tempInstaller -Encoding utf8
    $size = (Get-Item $tempInstaller).Length
    if ($size -lt 1000) {
        Say "[FAIL] Installer file looks too small ($size bytes). Aborting." "Red"
        Say "       Inspect $tempInstaller and report to Mau." "Red"
        exit 1
    }
    Say "[OK] Installer downloaded ($size bytes) -> $tempInstaller" "Green"
}
catch {
    Say "[FAIL] Failed to download installer: $($_.Exception.Message)" "Red"
    exit 1
}

Say ""
Say "Handing off to the Harvey installer (running in a child PowerShell)..." "Cyan"
Say ""

# Execute as a CHILD PowerShell process - guarantees clean parser context,
# proper encoding, and no inheritance of bootstrap variable scope.
# -NoProfile skips PROFILE.ps1 (faster, no surprises).
# -ExecutionPolicy Bypass since the temp file isn't signed.
$pwshArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $tempInstaller)
$pwshExe = (Get-Command pwsh -ErrorAction SilentlyContinue) ?? (Get-Command powershell -ErrorAction SilentlyContinue)
if (-not $pwshExe) {
    Say "[FAIL] Neither pwsh nor powershell on PATH (?!). Something is very broken." "Red"
    exit 1
}
& $pwshExe.Source @pwshArgs
$installExit = $LASTEXITCODE

# Keep the temp file if the install failed - aids debugging
if ($installExit -ne 0) {
    Say ""
    Say "[!] Installer exited with code $installExit. Temp file preserved at:" "Yellow"
    Say "    $tempInstaller" "Yellow"
    Say "    Send the file or its tail output to Mau." "Yellow"
    exit $installExit
}

# Success - clean up
Remove-Item $tempInstaller -ErrorAction SilentlyContinue
exit 0
