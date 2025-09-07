# this file is read for all sessions (interactive or not, login or not)

# xdg base directories https://wiki.archlinux.org/title/XDG_Base_Directory
export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_DATA_HOME="${HOME}/.local/share"
export XDG_CACHE_HOME="${HOME}/.cache"
export XDG_STATE_HOME="${HOME}/.local/state"

# zsh - Use xdg dirs for configs, zinit, completion
export ZDOTDIR="${XDG_CONFIG_HOME}/zsh"
export ZINIT_HOME="${XDG_DATA_HOME}/zinit/zinit.git"
export ZSH_COMPDUMP="${XDG_CACHE_HOME}/zsh/zcompdump-${ZSH_VERSION}"
