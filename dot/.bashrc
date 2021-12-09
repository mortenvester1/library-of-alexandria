# source aliases
if [ -e $HOME/.bash_aliases ]; then
    source $HOME/.bash_aliases
fi
# don't put duplicate lines or lines starting with space in the history.
# for setting history length
HISTCONTROL=ignoreboth
HISTSIZE=1000
HISTFILESIZE=2000

# append to the history file, don't overwrite it
shopt -s histappend
shopt -s checkwinsize

# simple color themes
export PS1="\[\033[36m\]\u\[\033[m\]@\[\033[32m\]\h:\[\033[33;1m\]\w\[\033[m\]\\$\[$(tput sgr0)\] "
export CLICOLOR=1


# Macbook setup
if [[ `uname -m` == 'arm64' ]] && [[ `uname` == 'Darwin' ]];
then
  #brew m1 install
  PATH=/opt/homebrew/bin:$PATH

  # ls color
  export LSCOLORS=ExFxBxDxCxegedabagacad

  # node version manager
  # curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.37.2/install.sh | bash
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
else
    # pi setup
    if [ -x /usr/bin/dircolors ]; then
        test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
        alias ls='ls --color=auto'

        alias grep='grep --color=auto'
        alias fgrep='fgrep --color=auto'
        alias egrep='egrep --color=auto'
    fi
fi
