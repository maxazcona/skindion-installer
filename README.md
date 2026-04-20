# skindion-installer

Public bootstrap repo for installing Skindion's Claude Code plugins on
team members' machines. The actual plugin code (Harvey + future agents)
lives in the private [maxazcona/skindion-agents](https://github.com/maxazcona/skindion-agents) repo.

## What's here

This repo only contains short bootstrap scripts. Each script:

1. Installs GitHub CLI (`gh`) if missing — via `winget` (Windows) or `brew`/`apt` (Mac/Linux)
2. Runs `gh auth login` if not already authenticated
3. Verifies the user's GitHub account has access to the private `skindion-agents` repo
4. Downloads the real installer for the requested agent via authenticated `gh api`
5. Executes it

This is "public bootstrap → private installer" so the public surface is minimal
(just gh install + auth) while the actual plugin source stays IP-protected.

## Install Harvey ✍️ (the copywriter)

### Windows 10 / 11 (PowerShell)

```powershell
iwr -useb https://raw.githubusercontent.com/maxazcona/skindion-installer/main/bootstrap-harvey.ps1 | iex
```

### macOS / Linux (bash)

```bash
curl -sSL https://raw.githubusercontent.com/maxazcona/skindion-installer/main/bootstrap-harvey.sh | bash
```

## Prerequisites the bootstrap CAN'T install for you

- **Claude Code desktop app** — install + log in first: https://claude.ai/download
- **A GitHub account that has been added** to the maxazcona org with access to `skindion-agents`. Ping Max if you're not sure.
- **The MCP wiki token** — Mau sends this in the invite email. The installer prompts you to paste it.

## Updating

Inside any Harvey chat in Claude Code, run `/update-harvey`. The slash command pulls the latest plugin version + reports what changed.

## Future agents

When Pulse, Valeria, or per-role assistants ship, they'll get their own
bootstrap script in this repo (e.g. `bootstrap-pulse.ps1`). One-liner pattern stays the same.
