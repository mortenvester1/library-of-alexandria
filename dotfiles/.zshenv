# Following https://www.drupaldump.com/right-way-migrate-your-bashprofile-zsh
# this file is all sessions (interactive or not)

# enabled colors in ls
export CLICOLOR=1
export LSCOLORS=ExGxBxDxCxEgEdxbxgxcxd

# java home
export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home/"
export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"

# config stuff
export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_DATA_HOME="${HOME}/.local/share"

# gpg signing
export GPG_TTY=$(tty)
