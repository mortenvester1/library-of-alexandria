# this file is for interactive sessions only, i.e. when a human is hammering on the keyboard
# Add to path, configure various programs, source aliases and secrets

# plugin manager for zsh
[ -d "${XDG_STATE_HOME}/zsh" ] || mkdir -p "${XDG_STATE_HOME}/zsh"
[ -d "${XDG_CACHE_HOME}/zsh" ] || mkdir -p "${XDG_CACHE_HOME}/zsh"
[ ! -d ${ZINIT_HOME} ] && mkdir -p "$(dirname ${ZINIT_HOME})"
[ ! -d ${ZINIT_HOME}/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "${ZINIT_HOME}"
source "${ZINIT_HOME}/zinit.zsh"

# HMMM does not take precedence as soon as there is an install in asdf regardless of it being used
# # direnv to use .envrc files in directories. Using direnv installation for faster load over eval "$(direnv hook zsh)"
# # also this direnv is added to path and takes precendence over installations from brew or asdf
# zinit as"program" make'!' atclone'./direnv hook zsh > zhook.zsh' \
#     atpull'%atclone' pick"direnv" src"zhook.zsh" for \
#     direnv/direnv

# Add plugins for completions, suggestions
zinit ice blockf
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-completions

# vim - create destination for viminfo
[ -d "${XDG_STATE_HOME}/vim" ] || mkdir -p "${XDG_STATE_HOME}/vim"

# homebrew - add to path
export PATH="/opt/homebrew/bin:$PATH" # takes precedence over system installs and direnv from zinit

# asdf - add packages/shims to path
export ASDF_DATA_DIR="${XDG_DATA_HOME}/asdf"
export PATH="${ASDF_DATA_DIR}/shims:$PATH" # takes precedence over brew installs

# asdf completions requires modification of fpath before compinit is run
[ -d "${ASDF_DATA_DIR}/completions" ] || mkdir -p "${ASDF_DATA_DIR}/completions"
asdf completion zsh > "${ASDF_DATA_DIR}/completions/_asdf"
fpath=(${ASDF_DATA_DIR}/completions $fpath)

# init completions with custom path for caching
zstyle ':completion:*' cache-path "${ZSH_COMPDUMP}"
autoload -Uz compinit && compinit -C -d "${ZSH_COMPDUMP}"

# Load other completions
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
[ -d "${DOCKER_CONFIG}" ] || mkdir -p ${DOCKER_CONFIG}

# k9s - config location
export K9SCONFIG="${XDG_CONFIG_HOME}/k9s"
[ -d "${K9SCONFIG}" ] || mkdir -p ${K9SCONFIG}

# ollama - data/models location
export OLLAMA_MODELS="${XDG_DATA_HOME}/ollama/models"
[ -d "${OLLAMA_MODELS}" ] || mkdir -p ${OLLAMA_MODELS}

# source additional .zsh files
[ -s "${ZDOTDIR}/.zsh_aliases" ] && source ${ZDOTDIR}/.zsh_aliases
[ -s "${ZDOTDIR}/.zsh_aliases.work" ] && source ${ZDOTDIR}/.zsh_aliases.work
[ -s "${ZDOTDIR}/.zshenv.secrets" ] && source ${ZDOTDIR}/.zshenv.secrets
