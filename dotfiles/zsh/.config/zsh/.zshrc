# This file is read in interactive shell sessions
# Use to configure various programs, aliases, secrets, etc.

# zinit setup
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

# Configure zsh
setopt APPENDHISTORY
setopt HIST_EXPIRE_DUPS_FIRST    # Expire a duplicate event first when trimming history.
setopt HIST_FIND_NO_DUPS         # Do not display a previously found event.
setopt HIST_IGNORE_ALL_DUPS      # Delete an old recorded event if a new event is a duplicate.
setopt HIST_IGNORE_DUPS          # Do not record an event that was just recorded again.
setopt HIST_IGNORE_SPACE         # Do not record an event starting with a space.
setopt HIST_SAVE_NO_DUPS         # Do not write a duplicate event to the history file.
setopt SHARE_HISTORY             # Share history between all sessions.

# OS dependent
# Set LS_COLORS
# on Linux set set source asdf
if [[ "$(uname)" == "Darwin" ]]
then
  eval $(gdircolors -b)
elif [[ "$(uname)" == "Linux" ]]
then
  eval $(dircolors -b)
fi

# hook direnv into zsh
eval "$(direnv hook zsh)"

# set up fzf keybindings and completions
source <(fzf --zsh)

# set GPG_TTY so pinentry knows which terminal to use
export GPG_TTY=$(tty)

# initialize starship prompt
eval "$(starship init zsh)"

# source additional .zsh files
[ -s "${ZDOTDIR}/aliases.zsh" ] && source ${ZDOTDIR}/aliases.zsh
[ -s "${ZDOTDIR}/completion.zsh" ] && source ${ZDOTDIR}/completion.zsh
[ -s "${ZDOTDIR}/.zshenv.local" ] && source ${ZDOTDIR}/.zshenv.local
[ -s "${ZDOTDIR}/.zprofile.local" ] && source ${ZDOTDIR}/.zprofile.local
[ -s "${ZDOTDIR}/.zshrc.local" ] && source ${ZDOTDIR}/.zshrc.local
