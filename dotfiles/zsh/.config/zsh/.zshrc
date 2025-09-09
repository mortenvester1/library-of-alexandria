# this file is for interactive sessions only, i.e. when a human is hammering on the keyboard
# Add to path, configure various programs, source aliases and secrets

# zsh
[ -d "${XDG_STATE_HOME}/zsh" ] || mkdir -p "${XDG_STATE_HOME}/zsh"
[ -d "${XDG_CACHE_HOME}/zsh" ] || mkdir -p "${XDG_CACHE_HOME}/zsh"

# vim - create destination for viminfo
[ -d "${XDG_STATE_HOME}/vim" ] || mkdir -p "${XDG_STATE_HOME}/vim"

# bash completion - used by some completions in zsh
export BASH_COMPLETION_USER_DIR="${XDG_DATA_HOME}/bash-completion"
[ -d "${BASH_COMPLETION_USER_DIR}" ] || mkdir -p "${BASH_COMPLETION_USER_DIR}"

# zinit setup
[ -d ${ZINIT_HOME} ] || mkdir -p "$(dirname ${ZINIT_HOME})"
[ -d ${ZINIT_HOME}/.git ] || git clone https://github.com/zdharma-continuum/zinit.git "${ZINIT_HOME}"
source "${ZINIT_HOME}/zinit.zsh"

# Add plugins for completions, suggestions
zinit ice blockf
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-history-substring-search
zinit light zdharma/fast-syntax-highlighting

# homebrew - add to path (precedence over system installs), setup completions
export HOMEBREW_BUNDLE_FILE_GLOBAL="${XDG_CONFIG_HOME}/homebrew/Brewfile"
eval "$(/opt/homebrew/bin/brew shellenv)"

# asdf - add packages/shims to path (# takes precedence over brew install+system)
export ASDF_DIR="${XDG_CONFIG_HOME}/asdf"
export ASDF_DATA_DIR="${XDG_DATA_HOME}/asdf"
export PATH="${ASDF_DATA_DIR}/shims:$PATH"

# asdf completions requires modification of fpath before compinit is run
[ -d "${ASDF_DATA_DIR}/completions" ] || mkdir -p "${ASDF_DATA_DIR}/completions"
asdf completion zsh > "${ASDF_DATA_DIR}/completions/_asdf"
fpath=(${ASDF_DATA_DIR}/completions $fpath)

# init completions with custom path for caching
autoload bashcompinit && bashcompinit
autoload -Uz compinit && compinit -C -d "${ZSH_COMPDUMP}"

# completion styling
# add colors like like in the ls command when completing files/directories. gdircolors -b exports LS_COLORS
eval $(gdircolors -b)
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' cache-path "${ZSH_COMPDUMP}"
zstyle ':completion:*' menu select # use arrow keys to select completion (or just tab)
zstyle ':completion:*' completer _complete _approximate # complete with typos

# reverse menu select through shift+tab
zmodload zsh/complist
bindkey '^[[Z' reverse-menu-complete

# Load completions
source <(uv --generate-shell-completion zsh)
source <(kubectl completion zsh)
source <(docker completion zsh)

# History
HISTSIZE=10000
HISTFILE="${XDG_STATE_HOME}/zsh/history"
SAVEHIST="${HISTSIZE}"
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

# gnupg - config location, enable signing
export GNUPGHOME="${XDG_CONFIG_HOME}/gnupg"
export GPG_TTY=$(tty)

# starship - set config, cache location, start
export STARSHIP_CONFIG="${XDG_CONFIG_HOME}/starship/starship.toml"
export STARSHIP_CACHE="${XDG_CACHE_HOME}/starship"
eval "$(starship init zsh)"

# python - set history, cache location
export PYTHON_HISTORY=${XDG_STATE_HOME}/python/python_history
export PYTHONPYCACHEPREFIX=${XDG_CACHE_HOME}/python
[ -d "${PYTHONPYCACHEPREFIX}" ] || mkdir -p ${PYTHONPYCACHEPREFIX}
[ -d $(dirname ${PYTHON_HISTORY}) ] || mkdir -p $(dirname ${PYTHON_HISTORY})

# Docker - config location
export DOCKER_CONFIG="${XDG_CONFIG_HOME}/docker"

# k9s - config location
export K9SCONFIG="${XDG_CONFIG_HOME}/k9s"

# ollama - data/models location
export OLLAMA_MODELS="${XDG_DATA_HOME}/ollama/models"
[ -d "${OLLAMA_MODELS}" ] || mkdir -p ${OLLAMA_MODELS}

# source additional .zsh files
[ -s "${ZDOTDIR}/.zsh_aliases" ] && source ${ZDOTDIR}/.zsh_aliases
[ -s "${ZDOTDIR}/.zshrc.local" ] && source ${ZDOTDIR}/.zshrc.local
