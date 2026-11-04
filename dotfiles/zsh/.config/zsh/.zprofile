# This file is read in login shell sessions
# Use for PATH manipulation

# homebrew - add to path (precedence over system installs)
# Set Brewfile destination
if [[ "$(uname)" == "Darwin" ]]
then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# XDG bin home for local executables
# Used by among other things by UV tools
export PATH="${XDG_BIN_HOME}:$PATH"

# LM Studio
export PATH="${PATH}:${HOME}/.lmstudio/bin"

# Source local PATH manipulation
[ -s "${ZDOTDIR}/.zprofile.local" ] && source ${ZDOTDIR}/.zprofile.local
