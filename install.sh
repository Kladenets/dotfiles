#!/usr/bin/env bash
# Codespaces dotfiles installer. Idempotent; safe to rerun.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NODE_MAJOR="${NODE_MAJOR:-24}"   # Node.js LTS line
OPENCODE_PKG="@opencode/cli"
NODE_HOME_DIR="$HOME/.local/node"
MARKER="# >>> dotfiles node path >>>"

log()  { printf '[dotfiles] %s\n' "$*"; }
warn() { printf '[dotfiles] WARNING: %s\n' "$*" >&2; }
die()  { printf '[dotfiles] ERROR: %s\n' "$*" >&2; exit 1; }

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then SUDO="sudo"; fi
fi

# Make a user-level bin dir visible to the rest of this script.
export PATH="$HOME/.local/bin:$NODE_HOME_DIR/bin:$PATH"

install_zsh() {
  if command -v zsh >/dev/null 2>&1; then
    log "zsh already installed."
    return 0
  fi
  log "Installing zsh..."
  if command -v apt-get >/dev/null 2>&1; then
    $SUDO apt-get update -y && $SUDO apt-get install -y zsh
  elif command -v apk >/dev/null 2>&1; then
    $SUDO apk add --no-cache zsh
  elif command -v dnf >/dev/null 2>&1; then
    $SUDO dnf install -y zsh
  else
    die "No supported package manager found; install zsh manually."
  fi
  command -v zsh >/dev/null 2>&1 || die "zsh installation failed."
}

install_ohmyzsh() {
  if [ -d "$HOME/.oh-my-zsh" ]; then
    log "Oh My Zsh already installed."
    return 0
  fi
  command -v git >/dev/null 2>&1 || die "git is required to install Oh My Zsh."
  log "Installing Oh My Zsh..."
  git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh" \
    || { rm -rf "$HOME/.oh-my-zsh"; die "Failed to clone Oh My Zsh."; }
}

link_zshrc() {
  local target="$HOME/.zshrc" src="$DOTFILES_DIR/.zshrc"
  if [ -L "$target" ] && [ "$(readlink "$target")" = "$src" ]; then
    return 0
  fi
  if [ -e "$target" ] || [ -L "$target" ]; then
    log "Backing up existing .zshrc to .zshrc.pre-dotfiles"
    mv -f "$target" "$target.pre-dotfiles"
  fi
  ln -s "$src" "$target"
  log "Linked $target -> $src"
}

set_default_shell() {
  local zsh_path current
  zsh_path="$(command -v zsh)"
  current="$(getent passwd "$(id -un)" | cut -d: -f7 || true)"
  if [ "$current" = "$zsh_path" ]; then
    log "zsh is already the login shell."
    return 0
  fi
  grep -qx "$zsh_path" /etc/shells 2>/dev/null || echo "$zsh_path" | $SUDO tee -a /etc/shells >/dev/null 2>&1 || true
  if $SUDO chsh -s "$zsh_path" "$(id -un)" >/dev/null 2>&1 || chsh -s "$zsh_path" >/dev/null 2>&1; then
    log "Default shell set to $zsh_path."
  else
    warn "Could not change the default shell; run 'zsh' manually. Continuing."
  fi
}

install_node() {
  if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    log "Node $(node --version) and npm $(npm --version) already available."
    return 0
  fi
  command -v curl >/dev/null 2>&1 || die "curl is required to download Node.js."
  command -v tar >/dev/null 2>&1 || die "tar is required to install Node.js."

  local arch os="linux"
  case "$(uname -m)" in
    x86_64) arch="x64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) die "Unsupported architecture: $(uname -m)" ;;
  esac

  local base="https://nodejs.org/dist/latest-v${NODE_MAJOR}.x"
  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  log "Installing Node.js v${NODE_MAJOR} LTS (${arch})..."
  curl -fsSL "$base/SHASUMS256.txt" -o "$tmp/SHASUMS256.txt" \
    || die "Could not download Node.js checksums from $base."
  local file
  file="$(awk -v s="-${os}-${arch}.tar.xz" '$2 ~ s"$" {print $2; exit}' "$tmp/SHASUMS256.txt")"
  [ -n "$file" ] || die "No Node.js ${NODE_MAJOR} build found for ${os}-${arch}."
  curl -fsSL "$base/$file" -o "$tmp/$file" || die "Could not download $file."
  (cd "$tmp" && grep " $file\$" SHASUMS256.txt | sha256sum -c -) \
    || die "Checksum verification failed for $file."

  rm -rf "$NODE_HOME_DIR"
  mkdir -p "$NODE_HOME_DIR"
  tar -xJf "$tmp/$file" -C "$NODE_HOME_DIR" --strip-components=1 \
    || die "Failed to extract Node.js (is xz installed?)."
  if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
    die "Node.js installed but node/npm not found on PATH."
  fi
  log "Installed Node $(node --version), npm $(npm --version)."
}

configure_path() {
  # Make node/npm and user-level bin dirs discoverable in bash and zsh.
  local rc
  for rc in "$HOME/.bashrc" "$HOME/.profile" "$HOME/.zshenv"; do
    touch "$rc"
    grep -qF "$MARKER" "$rc" && continue
    cat >> "$rc" <<'BLOCK'

# >>> dotfiles node path >>>
for _d in "$HOME/.local/node/bin" "$HOME/.local/bin" "$HOME/.npm-global/bin"; do
  [ -d "$_d" ] && case ":$PATH:" in *":$_d:"*) ;; *) PATH="$_d:$PATH" ;; esac
done
unset _d
export PATH
# <<< dotfiles node path <<<
BLOCK
  done
}

install_opencode() {
  command -v npm >/dev/null 2>&1 || die "npm not found; cannot install OpenCode."
  local prefix
  prefix="$(npm config get prefix)"
  if [ ! -w "$prefix" ] && [ ! -w "$prefix/lib" ] 2>/dev/null; then
    warn "npm prefix $prefix is not writable; using $HOME/.npm-global."
    export NPM_CONFIG_PREFIX="$HOME/.npm-global"
    mkdir -p "$NPM_CONFIG_PREFIX"
    export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"
  fi
  log "Installing OpenCode CLI ($OPENCODE_PKG)..."
  npm install --global --allow-scripts=@opencode/cli @opencode/cli@latest \
    || die "npm failed to install $OPENCODE_PKG. Check the output above."
  hash -r
  command -v opencode >/dev/null 2>&1 \
    || die "$OPENCODE_PKG installed but 'opencode' is not on PATH."
  log "OpenCode available: $(command -v opencode)"
}

install_zsh
install_ohmyzsh
link_zshrc
set_default_shell
install_node
configure_path
install_opencode
log "Done."
