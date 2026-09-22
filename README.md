# claude-launcher

Pick a project from a menu and land straight back in the Claude Code conversation you were having there — no `cd`, no lost context.

Without it, picking up yesterday's work means opening PowerShell, navigating to the right folder, and starting Claude Code — and a plain `claude` opens a **blank** session that knows nothing about what you did last time. This launcher does the navigating for you and resumes that folder's most recent conversation instead.

No install, no dependencies, no GUI. One `.ps1` file and a shortcut you can pin to the taskbar.

```
===================================
   Choose a Claude Code project
===================================

  [1]  cim-tools-loin-tracking
  [2]  parametrixACC
  [3]  TidsRegistrering

  [A]  Add a project
  [R]  Remove a project
  [Q]  Quit

  Config: C:\Users\you\.claude-launcher.json

Type a number or letter and press Enter:
```

## Requirements

- Windows with PowerShell 5.1 (built in) or newer
- Claude Code installed and on your `PATH` — check with `claude --version`

## Setup

1. Download or clone this repo:

   ```powershell
   git clone https://github.com/NikolajGranzow/claude-launcher.git
   ```

2. Create a desktop shortcut:

   ```powershell
   .\Install-Shortcut.ps1
   ```

3. Right-click the new **Claude Launcher** shortcut on your desktop and choose **Pin to taskbar**.

That's it. Open it and press `A` to add your first project.

You can also just run `.\claude-launcher.ps1` directly whenever you want it.

## How it works

Pick a number and the script changes into that folder and runs:

```powershell
claude -c
```

`-c` is Claude Code's "continue" flag: it reopens the **most recent conversation started in the current directory**, with the full history and everything Claude had already worked out about your code still in context. You pick up mid-thread — no re-explaining the project, no repeating what you tried yesterday.

So the two steps you'd otherwise do by hand — `cd` to the project, then remember to pass `-c` — both happen for you. Pressing `1` on the taskbar shortcut is the whole workflow.

### What you get back

Conversations are per-folder, and Claude Code stores them itself under `%USERPROFILE%\.claude\projects\`. The launcher doesn't keep any history of its own; it just makes sure Claude Code is started in the right place with the right flag, so it finds the session that belongs to that project.

That means:

- Each project resumes **its own** last conversation — switching between them in the menu never mixes them up.
- A conversation survives closing the window, and reboots. Come back a week later and it's still there.
- First time in a new project there's nothing to resume, so `claude -c` exits with an error instead of starting fresh. The script catches that and starts a new session for you — you'll see *"No previous conversation here - starting a new session..."* and land in an empty prompt. From then on that project resumes like the rest.

Want a clean slate in a project that already has history? Quit the launcher and run plain `claude` in that folder — or type `/clear` in the running session.

## Your project list

Projects are stored in a JSON file, by default at `%USERPROFILE%\.claude-launcher.json`:

```json
[
    {
        "Name":  "my-project",
        "Path":  "C:\\Users\\you\\Projects\\my-project"
    }
]
```

You never need to edit it by hand — `[A]` and `[R]` in the menu do it for you. When adding a project you can paste the path or drag the folder straight into the terminal window.

The list lives outside the repo on purpose, so pulling updates never touches your projects and your local paths never end up in a commit.

Want the list somewhere else (a synced folder, for instance)? Pass a path:

```powershell
.\claude-launcher.ps1 -ConfigPath "C:\Users\you\OneDrive\claude-launcher.json"
```

If you do that, update the `Arguments` line in your shortcut to match.

## Notes

- Removing a project only takes it off the menu. Nothing on disk is deleted.
- If a folder gets moved or renamed, the menu marks it `(folder missing)` and refuses to launch there — remove it and add it back at its new location.
- Execution policy: the shortcut passes `-ExecutionPolicy Bypass`, so no system-wide policy change is needed. Running the script from an existing prompt may require `Unblock-File .\claude-launcher.ps1` first if Windows flagged the download.

## License

MIT — see [LICENSE](LICENSE).
