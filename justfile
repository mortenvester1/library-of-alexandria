default:
    just --list

# create a gitlocal file
create-gitlocal email gpg_key:
    #!/bin/bash
    cat > ${XDG_CONFIG_HOME}/git/.gitlocal << EOL
    [user]
      email = {{ email }}
      signingkey = {{ gpg_key }}
    [commit]
      gpgsign = true
    EOL

# Generate a ssh-key for user with key_postfix and optional password
create-ssh-key user key_postfix password="":
    #!/bin/bash
    ssh-keygen -t ed25519 -C {{ user }} -N {{ password }} -f ~/.ssh/id_ed25519_{{ key_postfix }}
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/id_ed25519_{{ key_postfix }}
    pbcopy < ~/.ssh/id_ed25519_{{ key_postfix }}
    echo "ssh key has been added to agent and copied to pasteboard. Now add it where needed"

# Generate a gpg-key for email with password
create-gpg-key email password:
    #!/bin/bash
    gpg --quick-gen-key --batch --passphrase {{ password }} {{ email }}
    KEY_ID=$(gpg --list-secret-keys --keyid-format=long | grep -C 2 {{ email }} | grep ed25519 | tr -s ' ' | cut -d ' ' -f 2 | cut -d '/' -f 2)
    gpg --armor --export $KEY_ID | pbcopy
    echo "gpg key '${KEY_ID}' has been created. Now add it where needed"

# Upgrade install based on local repo
upgrade:
    #!/bin/zsh
    SKIP_GIT=1 ./install.sh
