# This file is read in all shell sessions (interactive or not, login or not)
# Use to define new environment variables and create required directories

# This ensures that /etc/zsh/zshrc doens't load compinit in ubuntu
export skip_global_compinit=1

# xdg base directories https://wiki.archlinux.org/title/XDG_Base_Directory
export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_DATA_HOME="${HOME}/.local/share"
export XDG_CACHE_HOME="${HOME}/.cache"
export XDG_STATE_HOME="${HOME}/.local/state"

# asdf
export ASDF_DIR="${XDG_CONFIG_HOME}/asdf"
export ASDF_DATA_DIR="${XDG_DATA_HOME}/asdf"

[ -d "${ASDF_DATA_DIR}/completions" ] || mkdir -p "${ASDF_DATA_DIR}/completions"

# bash completion - used by some completions in zsh
export BASH_COMPLETION_USER_DIR="${XDG_DATA_HOME}/bash-completion"
[ -d "${BASH_COMPLETION_USER_DIR}" ] || mkdir -p "${BASH_COMPLETION_USER_DIR}"

# Claude - not used atm as claude in zed uses sh and not zsh so
# it doesn't read this var
# export CLAUDE_CONFIG_DIR="${XDG_CONFIG_HOME}/claude"

# Docker - config is just default. They don't yet support xdg
# https://github.com/docker/roadmap/issues/408
export DOCKER_CONFIG="${HOME}/.docker"

# gnupg - config location
export GNUPGHOME="${XDG_CONFIG_HOME}/gnupg"

# ollama - data/models location
export OLLAMA_MODELS="${XDG_DATA_HOME}/ollama/models"
[ -d "${OLLAMA_MODELS}" ] || mkdir -p ${OLLAMA_MODELS}

# k9s - config location
export K9SCONFIG="${XDG_CONFIG_HOME}/k9s"

# python - set history, cache location
export PYTHON_HISTORY=${XDG_STATE_HOME}/python/python_history
export PYTHONPYCACHEPREFIX=${XDG_CACHE_HOME}/python
[ -d "${PYTHONPYCACHEPREFIX}" ] || mkdir -p ${PYTHONPYCACHEPREFIX}
[ -d $(dirname ${PYTHON_HISTORY}) ] || mkdir -p $(dirname ${PYTHON_HISTORY})

# starship
export STARSHIP_CONFIG="${XDG_CONFIG_HOME}/starship/starship.toml"
export STARSHIP_CACHE="${XDG_CACHE_HOME}/starship"

# vim - create destination for viminfo
[ -d "${XDG_STATE_HOME}/vim" ] || mkdir -p "${XDG_STATE_HOME}/vim"

# zsh - Use xdg dirs for configs, zinit, completion cache
export ZDOTDIR="${XDG_CONFIG_HOME}/zsh"
export ZSH_COMPDUMP="${XDG_CACHE_HOME}/zsh/zcompdump-${ZSH_VERSION}"
export ZSH_COMPLETIONS_DIR="${XDG_CACHE_HOME}/zsh/completions"
export ZINIT_HOME="${XDG_DATA_HOME}/zinit/zinit.git"

[ -d ${ZINIT_HOME} ] || mkdir -p "$(dirname ${ZINIT_HOME})"
[ -d "${XDG_STATE_HOME}/zsh" ] || mkdir -p "${XDG_STATE_HOME}/zsh"
[ -d "${XDG_CACHE_HOME}/zsh" ] || mkdir -p "${XDG_CACHE_HOME}/zsh"
[ -d "${ZSH_COMPLETIONS_DIR}" ] || mkdir -p "${ZSH_COMPLETIONS_DIR}"

# zsh history setup
export HISTSIZE=10000
export HISTFILE="${XDG_STATE_HOME}/zsh/history"
export SAVEHIST="${HISTSIZE}"
