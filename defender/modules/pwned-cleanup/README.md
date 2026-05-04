# pwned-cleanup

Deletes `C:\Users\Public\Documents\pwned.txt` if the file exists.

## Approach

- If the file does not exist, no error is thrown.
- If it exists, it is deleted with `Remove-Item -Force`.

## Return value

`[PSCustomObject]` with `Module`, `Findings`, `Actions`, `Success`.
