#!/bin/zsh

# regenerate external completions if they are older than executeble
mkdir -p ${ZSH_COMPLETIONS_DIR}
if [ ! -f "${ZSH_COMPLETIONS_DIR}/_asdf" ] || [ "${ZSH_COMPLETIONS_DIR}/_asdf" -ot "$(which asdf)" ]; then
  asdf completion zsh > "${ZSH_COMPLETIONS_DIR}/_asdf"
fi;

if [ ! -f "${ZSH_COMPLETIONS_DIR}/_uv" ] || [ "${ZSH_COMPLETIONS_DIR}/_uv" -ot "$(which uv)" ]; then
  uv --generate-shell-completion zsh > "${ZSH_COMPLETIONS_DIR}/_uv"
fi

if [ ! -f "${ZSH_COMPLETIONS_DIR}/_kubectl" ] || [ "${ZSH_COMPLETIONS_DIR}/_kubectl" -ot "$(which kubectl)" ]; then
  kubectl completion zsh > "${ZSH_COMPLETIONS_DIR}/_kubectl"
fi

if [ ! -f "${ZSH_COMPLETIONS_DIR}/_docker" ] || [ "${ZSH_COMPLETIONS_DIR}/_docker" -ot "$(which docker)" ]; then
  docker completion zsh > "${ZSH_COMPLETIONS_DIR}/_docker"
fi

# Add dir to fpath so compinit will scan
fpath=(${ZSH_COMPLETIONS_DIR} $fpath)

# init completion
autoload bashcompinit && bashcompinit # for aws-cli and others
autoload -Uz compinit && compinit -C -d "${ZSH_COMPDUMP}" # with cache + set location

setopt GLOBDOTS      # Complete hidden files
setopt MENU_COMPLETE # Highlight first element of completion menu on first tab
setopt LIST_PACKED   # The completion menu takes less space
setopt AUTO_PARAM_SLASH # When a directory is completed, add a trailing slash instead of a space.

# define completers. _approximate can fix typos, at most 2 errors
zstyle ':completion:*' completer _complete _approximate
zstyle ':completion:*' max-errors 2

# Menu selection
zstyle ':completion:*' menu select

# add colors
zstyle ':completion:*:default' list-colors "${(s.:.)LS_COLORS}"

# sort by name
zstyle ':completion:*' file-sort name

# reverse menu select through shift+tab
zmodload zsh/complist
bindkey '^[[Z' reverse-menu-complete
