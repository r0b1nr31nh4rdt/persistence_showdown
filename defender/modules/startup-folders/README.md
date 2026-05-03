# startup-folders

Clears both Windows Startup folders completely — no whitelist comparison, since no legitimate content is expected on the challenge VM.

## Checked

- `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup` (User)
- `C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup` (Public)

## Approach

All files in both folders are deleted with `Remove-Item -Force`. Subdirectories are not cleaned recursively (only files directly in the startup folder).

## Return value

`[PSCustomObject]` with `Module`, `Findings`, `Actions`, `Success`.
