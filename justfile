default:
    just --list

# create a gitlocal file
create-gitlocal email gpg_key:
    #!/bin/bash
    cat > dotfiles/git/.config/git/.gitlocal << EOL
    [user]
      email = {{ email }}
      signingkey = {{ gpg_key }}
    [commit]
      gpgsign = true
    EOL

    just stow git

# Generate a ssh-key for user with key_postfix and optional password
create-ssh-key user key_postfix password="":
    #!/bin/bash
    ssh-keygen -t ed25519 -C {{ user }} -N "{{ password }}" -f ~/.ssh/id_ed25519_{{ key_postfix }}
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/id_ed25519_{{ key_postfix }}
    echo "copy '~/.ssh/id_ed25519_{{ key_postfix }}.pub' to pasteboard and add where it is needed"

# Create ~/.ssh/config with GitHub host entry
create-ssh-config key_postfix:
    #!/bin/bash
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    cat > ~/.ssh/config << EOL
    Host github.com
      AddKeysToAgent yes
      IdentityFile ~/.ssh/id_ed25519_{{ key_postfix }}
    EOL

# Generate a gpg-key for email with password
create-gpg-key name email password:
    #!/bin/bash
    gpg --quick-gen-key --batch --passphrase {{ password }} "{{ name }} <{{ email }}>"
    KEY_ID=$(gpg --list-secret-keys --keyid-format=long | grep -C 2 {{ email }} | grep ed25519 | tr -s ' ' | cut -d ' ' -f 2 | cut -d '/' -f 2)
    gpg --armor --export $KEY_ID
    echo "gpg key '${KEY_ID}' has been created."
    echo "copy to pasteboard and add where it is needed"

# restow a package
stow pkg:
    stow --target ${HOME} --dir "dotfiles" -R --no-folding {{ pkg }}

# Upgrade install based on local repo
upgrade:
    @SKIP_GIT=1 ./install.sh

dev-ubuntu-build:
    docker build -t ubuntu-w-zsh:local .

dev-ubuntu-install: dev-ubuntu-build
    # Set working directory and run script
    docker run --rm -it \
      --user ubuntu \
      -v /Users/mortenvester1/git/library-of-alexandria:/home/ubuntu/git/library-of-alexandria \
      -w /home/ubuntu/git/library-of-alexandria \
      ubuntu-w-zsh:local \
      /bin/bash -c "SKIP_GIT=1 ./install.sh"
