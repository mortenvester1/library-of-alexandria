# Following https://www.drupaldump.com/right-way-migrate-your-bashprofile-zsh
# this file is for interactive sessions only
# source aliases nand runs other configuration

[ -s "$HOME/.zsh_aliases" ] && source $HOME/.zsh_aliases
[ -s "$HOME/.zsh_aliases.work" ] && source $HOME/.zsh_aliases.work
[ -s "$HOME/.zshenv.secrets" ] && source $HOME/.zshenv.secrets

# plugin manager for zsh
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh"

# Add plugins for completions, suggestions, syntax
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-completions

# Not sure if I like just yet
# zinit light zsh-users/zsh-syntax-highlighting
# zinit light Aloxaf/fzf-tab

# Add asdf packages to path
# export of PATH must be here and not in .zshenv, otherwise python will point to asdf and python3 to system package
export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"
mkdir -p "${ASDF_DATA_DIR:-$HOME/.asdf}/completions"
asdf completion zsh > "${ASDF_DATA_DIR:-$HOME/.asdf}/completions/_asdf"

# Load completions
autoload -U compinit && compinit
source <(kubectl completion zsh)

# History
HISTSIZE=10000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUPE=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# fzf
source <(fzf --zsh)

# direnv to use .envrc files in directories
eval "$(direnv hook zsh)"

# starship
export STARSHIP_CONFIG="${XDG_CONFIG_HOME}/starship/starship.toml"
eval "$(starship init zsh)"

# Docker autocomplete
fpath=(${HOME}/.docker/completions $fpath)
autoload -Uz compinit
compinit
