# bootstrap-harvey.ps1 - Public bootstrap for the Skindion Harvey plugin
# Usage: iwr -useb https://raw.githubusercontent.com/maxazcona/skindion-installer/main/bootstrap-harvey.ps1 | iex

$ErrorActionPreference = "Stop"

function C($t, $col) { Write-Host $t -ForegroundColor $col }

function Banner {
    Write-Host ""
    C "    +--------------------------------------------------+" "Magenta"
    C "    |                                                  |" "Magenta"
    C "    |          S K I N D I O N    A G E N T S          |" "Magenta"
    C "    |                                                  |" "Magenta"
    C "    |          H A R V E Y    -   copywriter           |" "Magenta"
    C "    |                                                  |" "Magenta"
    C "    +--------------------------------------------------+" "Magenta"
    Write-Host ""
    C "    Bootstrapping installer for the Harvey copywriter plugin." "Cyan"
    C "    One-time setup. Re-runs are idempotent." "DarkGray"
    Write-Host ""
}

$global:Step = 0
function Step($n, $msg) {
    $global:Step = $n
    Write-Host ""
    C "  [$n/4] $msg" "Yellow"
}
function OK($msg)   { C "       OK   $msg" "Green" }
function Warn($msg) { C "       WARN $msg" "Yellow" }
function Fail($msg) {
    C "       FAIL $msg" "Red"
    Write-Host ""
    C "  Install aborted at step $global:Step." "Red"
    C "  Need help? ping #harvey-support or mau@skindion.com" "Red"
    Write-Host ""
    exit 1
}

Banner

# 1. gh CLI
Step 1 "Verifying GitHub CLI (gh)..."
$gh = Get-Command gh -ErrorAction SilentlyContinue
if (-not $gh) {
    Warn "gh not installed - installing via winget (~1 min)..."
    try {
        winget install --id GitHub.cli --silent --accept-source-agreements --accept-package-agreements | Out-Null
        $env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User")
        $gh = Get-Command gh -ErrorAction SilentlyContinue
        if (-not $gh) { Fail "gh installed but PATH did not refresh. Open a new PowerShell window + re-run bootstrap." }
        OK "gh installed"
    } catch { Fail "winget install failed. Install gh manually from https://cli.github.com/" }
} else {
    OK "gh present"
}

# 2. gh auth
Step 2 "Verifying GitHub login..."
& gh auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Warn "Not logged in - opening browser for OAuth..."
    C "       (Click 'Authorize' in the browser tab, then return here.)" "DarkGray"
    & gh auth login --web --git-protocol https --hostname github.com
    if ($LASTEXITCODE -ne 0) { Fail "gh auth login did not complete. Run 'gh auth login' manually + re-run bootstrap." }
    OK "logged in"
} else {
    OK "already logged in"
}

# 3. Repo access
Step 3 "Verifying access to private maxazcona/skindion-agents repo..."
& gh api repos/maxazcona/skindion-agents 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    C "" 
    C "       Your GitHub account is not yet a collaborator on the" "Red"
    C "       maxazcona/skindion-agents repo. Ping Max with your" "Red"
    C "       GitHub username so he can add you, then re-run." "Red"
    Fail "no repo access"
}
OK "you have access"

# 4. Download + run installer
Step 4 "Downloading the Harvey installer..."
$tempInstaller = Join-Path $env:TEMP "harvey-install-$(Get-Random).ps1"
try {
    & gh api -H "Accept: application/vnd.github.raw" "repos/maxazcona/skindion-agents/contents/agents/harvey/install/harvey-win.ps1" | Out-File -FilePath $tempInstaller -Encoding utf8
    $size = (Get-Item $tempInstaller).Length
    if ($size -lt 1000) { Fail "Downloaded installer is too small ($size bytes). Aborting." }
    OK ("downloaded ({0:N1} KB)" -f ($size / 1024))
} catch { Fail "Download failed: $($_.Exception.Message)" }

Write-Host ""
C "    +--------------------------------------------------+" "DarkCyan"
C "    |  Bootstrap done. Handing off to Harvey installer.|" "DarkCyan"
C "    |  Next part will ask for your MCP_WIKI_TOKEN.     |" "DarkCyan"
C "    |  (Mau sent it in the invite email - have ready.) |" "DarkCyan"
C "    +--------------------------------------------------+" "DarkCyan"
Write-Host ""

$pwshExe = Get-Command pwsh -ErrorAction SilentlyContinue
if (-not $pwshExe) { $pwshExe = Get-Command powershell -ErrorAction SilentlyContinue }
if (-not $pwshExe) { Fail "Neither pwsh nor powershell on PATH (should not happen)" }

& $pwshExe.Source -NoProfile -ExecutionPolicy Bypass -File $tempInstaller
$installExit = $LASTEXITCODE

if ($installExit -ne 0) {
    Write-Host ""
    C "  Installer exited with code $installExit." "Red"
    C "  Temp file kept for debugging: $tempInstaller" "Yellow"
    C "  Send the file (or last 30 lines) to Mau." "Yellow"
    exit $installExit
}

Remove-Item $tempInstaller -ErrorAction SilentlyContinue
exit 0
