# OS Project 4 - Persistence Showdown

Red vs. Blue Team Persistence Challenge on Windows VMs.

## Team B
Alex, Jacob, Robin, Stefan

## Rules

1. Attacker script runs → sets persistence mechanisms
2. Defender script runs → finds and removes persistence mechanisms
3. Reboot
4. Does `C:\Users\Public\Documents\pwned.txt` contain "Pwn3d"?
   - YES → Attacker wins
   - NO → Defender wins

## Competition Result

https://r0b1nr31nh4rdt.github.io/persistence_showdown/Showdown-Report.html

## Structure
```
project_7_persistent_showdown/
├── attacker/
│   ├── build.ps1
│   ├── attacker_final.ps1     ← generated locally, not in repo
│   └── modules/
│       └── your-module/
│           ├── your-script.ps1
│           └── README.md
├── defender/
│   ├── build.ps1
│   ├── defend_final.ps1       ← generated locally, not in repo
│   └── modules/
│       └── your-module/
│           ├── your-script.ps1
│           └── README.md
├── shared/
│   ├── baseline.ps1
│   └── whitelist.json
└── README.md
```

## Workflow

Always start by syncing with the latest develop branch:

```bash
# 1. Sync with develop
git checkout develop
git pull
git checkout feature/your-module
git merge develop

# 2. Build (on Windows VM)
.\build.ps1

# 3. Test
.\attacker_final.ps1   # or defend_final.ps1
```

The generated `_final.ps1` files are local only – never edit them directly.

## Submitting your work

Open a Pull Request from your feature branch into `develop`. So Robin can review and merge. Please don't merge from `develop` into `main` or direct into main.

## Notes

- Keep each script in its own subfolder within `modules/`
- Keep each script independent - the builder runs recursively through the folders
- Add a `README.md` to your subfolder explaining what your module does
- The shared whitelist is in `shared/whitelist.json`
- Test on Windows VM only

