#!/bin/zsh

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

# source external completions
source <(uv --generate-shell-completion zsh)
source <(kubectl completion zsh)
source <(docker completion zsh)
