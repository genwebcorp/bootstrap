# bootstrap

Public, first-mile bootstrap for setting up a GenWeb development environment on macOS or Linux.

## Usage

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/genwebcorp/bootstrap/main/bootstrap_initial.sh)"
```

## What it does

1. Installs [Homebrew](https://brew.sh) (if missing) and adds it to your shell startup files.
2. Installs the baseline tools: `gh`, `git`, and `go-task`.
3. Runs `gh auth login` over HTTPS (browser-based) if you're not already authenticated.
4. Clones `genwebcorp/genweb` to `~/genweb`.
5. Runs `task bootstrap` to set up the full development environment.

## Configuration

| Variable          | Default              | Description                          |
| ----------------- | -------------------- | ------------------------------------ |
| `GENWEB_REPO`     | `genwebcorp/genweb`  | Repository to clone.                 |
| `GENWEB_REPO_DIR` | `$HOME/genweb`       | Where to clone it.                   |

## Prerequisites

- A member account in the `genwebcorp` GitHub organization (ask your team to add you).

## Next steps

Once it finishes, run `task manage` from your checkout to provision and connect to a dev VM.
The full walkthrough lives in the genweb repo at `docs/how-to/DEV_VM_SETUP.md`.
