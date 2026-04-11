# This file is read in login shell sessions
# Use to PATH manipulation

# homebrew - add to path (precedence over system installs)
# Set Brewfile destination
if [[ "$(uname)" == "Darwin" ]]
then
  eval "$(/opt/homebrew/bin/brew shellenv)"
  export HOMEBREW_BUNDLE_FILE_GLOBAL="${XDG_CONFIG_HOME}/homebrew/Brewfile.darwin"
elif [[ "$(uname)" == "Linux" ]]
then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  export HOMEBREW_BUNDLE_FILE_GLOBAL="${XDG_CONFIG_HOME}/homebrew/Brewfile.linux"
fi

# XDG bin home for local executables
# Used by among other things by UV tools
export PATH="${XDG_BIN_HOME}:$PATH"

# asdf - add packages/shims to path (# takes precedence over brew install+system)
export PATH="${ASDF_DATA_DIR}/shims:$PATH"

# LM Studio
export PATH="${PATH}:${HOME}/.lmstudio/bin"
