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

# Add plugins
zinit ice blockf
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-history-substring-search
zinit light zdharma/fast-syntax-highlighting
zinit light ArielTM/zsh-claude-code-shell
autoload -U zmv

# History
export HISTSIZE=10000
export HISTFILE="${XDG_STATE_HOME}/zsh/history"
export SAVEHIST="${HISTSIZE}"
export HISTDUPE=erase

setopt APPENDHISTORY
setopt HIST_EXPIRE_DUPS_FIRST    # Expire a duplicate event first when trimming history.
setopt HIST_FIND_NO_DUPS         # Do not display a previously found event.
setopt HIST_IGNORE_ALL_DUPS      # Delete an old recorded event if a new event is a duplicate.
setopt HIST_IGNORE_DUPS          # Do not record an event that was just recorded again.
setopt HIST_IGNORE_SPACE         # Do not record an event starting with a space.
setopt HIST_SAVE_NO_DUPS         # Do not write a duplicate event to the history file.
setopt SHARE_HISTORY             # Share history between all sessions.

# asdf variables
export ASDF_DIR="${XDG_CONFIG_HOME}/asdf"
export ASDF_DATA_DIR="${XDG_DATA_HOME}/asdf"

# OS dependent
# homebrew - add to path (precedence over system installs)
# Set Brewfile destination
# Set LS_COLORS
# on Linux set set source asdf
if [[ "$(uname)" == "Darwin" ]]
then
  eval "$(/opt/homebrew/bin/brew shellenv)"
  eval $(gdircolors -b)
  export HOMEBREW_BUNDLE_FILE_GLOBAL="${XDG_CONFIG_HOME}/homebrew/Brewfile.darwin"
elif [[ "$(uname)" == "Linux" ]]
then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  eval $(dircolors -b)
  export HOMEBREW_BUNDLE_FILE_GLOBAL="${XDG_CONFIG_HOME}/homebrew/Brewfile.linux"
fi

# asdf - add packages/shims to path (# takes precedence over brew install+system)
export PATH="${ASDF_DATA_DIR}/shims:$PATH"

# asdf completions requires modification of fpath before compinit is run
[ -d "${ASDF_DATA_DIR}/completions" ] || mkdir -p "${ASDF_DATA_DIR}/completions"
asdf completion zsh > "${ASDF_DATA_DIR}/completions/_asdf"
fpath=(${ASDF_DATA_DIR}/completions $fpath)

# direnv
eval "$(direnv hook zsh)"

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

# Docker - config is just default. They don't yet support xdg
# https://github.com/docker/roadmap/issues/408
export DOCKER_CONFIG="${HOME}/.docker"

# k9s - config location
export K9SCONFIG="${XDG_CONFIG_HOME}/k9s"

# ollama - data/models location
export OLLAMA_MODELS="${XDG_DATA_HOME}/ollama/models"
[ -d "${OLLAMA_MODELS}" ] || mkdir -p ${OLLAMA_MODELS}

# Add LM Studio CLI (lms) to path
export PATH="${PATH}:/Users/mortenvester1/.lmstudio/bin"

# Claude
export CLAUDE_CONFIG_DIR="${XDG_CONFIG_HOME}/claude"

# source additional .zsh files
[ -s "${ZDOTDIR}/aliases.zsh" ] && source ${ZDOTDIR}/aliases.zsh
[ -s "${ZDOTDIR}/completion.zsh" ] && source ${ZDOTDIR}/completion.zsh
[ -s "${ZDOTDIR}/.zshrc.local" ] && source ${ZDOTDIR}/.zshrc.local
