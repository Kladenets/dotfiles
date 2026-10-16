# dotfiles

Personal dotfiles for GitHub Codespaces. Codespaces clones this repo and runs the root-level `install.sh`.

## What `install.sh` does (idempotent)

1. Installs `zsh` (apt/apk/dnf) and Oh My Zsh (`~/.oh-my-zsh`) if missing.
2. Symlinks `.zshrc` to `~/.zshrc` (an existing file is moved to `~/.zshrc.pre-dotfiles`). Codespaces does not do this for non-standard setups, so the script does it itself.
3. Tries to make zsh the login shell; a failure only prints a warning.
4. If `node`/`npm` are missing, installs the Node.js 24 LTS tarball (checksum-verified from nodejs.org) into `~/.local/node` and adds it to PATH via `~/.bashrc`, `~/.profile` and `~/.zshenv`. Override the line with `NODE_MAJOR=<n>`.
5. Runs `npm install --global --allow-scripts=@opencode/cli @opencode/cli@latest`. Any failure stops the script with a non-zero exit and an error message.

Not included: secrets (add OpenRouter keys as Codespaces secrets), the OpenCode VS Code extension and VS Code terminal settings (use Settings Sync).

## Enable

GitHub → Settings → Codespaces → Dotfiles → check "Automatically install dotfiles" and select this repository. Applies to new codespaces (or rebuild existing ones). Logs: `/workspaces/.codespaces/.persistedshare/creation.log`.

## Compatibility notes

- Package: the command above is the one from my existing setup. The OpenCode docs I know of list `npm i -g opencode-ai` (also a curl installer); I could not reach opencode.ai or the Codespaces docs from the authoring environment, so verify against the current docs. `@opencode/cli` is published by the same maintainer and provides the `opencode` binary. Change `install_opencode` in `install.sh` if you switch.
- `--allow-scripts` is a newer npm option; older npm versions warn about an unknown flag but still install.
- Node is installed from the official tarball, not apt/NodeSource, so no root is needed and it works regardless of the base image. Preexisting Node installs are left untouched. If npm's global prefix isn't writable, `~/.npm-global` is used.
- Changing the login shell may be blocked in some images; run `zsh` manually or set it in VS Code.

## Troubleshooting

- `zsh` missing: check the creation log; run `sudo apt-get update && sudo apt-get install -y zsh`, then `./install.sh`.
- `node`/`npm` missing: open a new shell (PATH is set in rc files) or `export PATH="$HOME/.local/node/bin:$PATH"`; rerun `./install.sh` (needs `curl`, `tar`, `xz`).
- `opencode` missing: run `npm ls -g --depth=0` and `npm config get prefix`; ensure `$(npm config get prefix)/bin` is on PATH, then rerun the npm command.
