# Reasonix Lock Cleanup

Auto-clean **orphan session lease locks** on every SessionStart, eliminating false
**"workspace occupied" / "session already open ... still running in the background"**
errors when opening multiple projects.

## What it fixes

When a Reasonix session exits abnormally (crash, force-kill, shutdown), Reasonix
leaves a `*-recovery-*.jsonl.lease.lock` + `*.jsonl.lock` behind, marking the
session as "still running in the background". Opening any project that has such a
leftover then reports an occupied/busy error — regardless of folder location or
task. This plugin removes those orphan locks automatically at every session start.

## Requirements

- **Windows** (the hook script is PowerShell)
- **Reasonix Desktop v1.20.0+** (native `reasonix-plugin.json` hooks support)
- PowerShell + Git Bash (bundled with Reasonix Desktop for Windows)

## Install

1. Get this folder (`reasonix-lock-cleanup`) on the target machine;
2. Reasonix Desktop → **Settings → Plugins → Install** → **choose local folder**;
3. Select the `reasonix-lock-cleanup` folder;
4. Done. Every new session automatically cleans orphan locks.

## What it deletes (safety)

- Only `*.lease.lock` / `*.jsonl.lock` under `%APPDATA%\reasonix\projects\...\sessions\`
  whose session file is **NOT** in the currently open tabs (`desktop-tabs.json`);
- Never touches active-session locks (protected by the OS anyway);
- Never touches `.display.json.lock` / `.planner-display.json.lock` state locks;
- Never deletes any conversation data (`.jsonl` transcripts are kept).

## How it works

- `reasonix-plugin.json` registers a `SessionStart` hook (`shell=auto`, 30s timeout);
- `cleanup-locks.ps1` reads `%APPDATA%\reasonix\desktop-tabs.json`
  (UTF-8!) to build the active-session set, then deletes every orphan lock;
- Prints nothing on success (SessionStart stdout would be injected into the
  model context).

## Layout

```
reasonix-lock-cleanup/
├── reasonix-plugin.json   # manifest (hook declaration)
└── cleanup-locks.ps1     # the cleanup script
```
