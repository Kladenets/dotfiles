# Minimal Oh My Zsh config for Codespaces.
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
DISABLE_AUTO_UPDATE="true"   # avoid network work at shell startup
plugins=(git)

# Ensure node/npm/opencode are found (also set in ~/.zshenv by install.sh).
for _d in "$HOME/.local/node/bin" "$HOME/.local/bin" "$HOME/.npm-global/bin"; do
  [ -d "$_d" ] && case ":$PATH:" in *":$_d:"*) ;; *) PATH="$_d:$PATH" ;; esac
done
unset _d
export PATH

[ -f "$ZSH/oh-my-zsh.sh" ] && source "$ZSH/oh-my-zsh.sh"
