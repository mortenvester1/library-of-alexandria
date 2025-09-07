default:
    just --list

# create a gitlocal file
create-gitlocal email gpg-key:
    #!/bin/bash
    cat > newfile.txt << EOL
    [user]
      email = {{email}}
      signingkey = {{gpg-key}}
    [commit]
      gpgsign = true
    EOL

# Generate a ssh-key for user with key_postfix
create-ssh-key user key_postfix password="":
    #!/bin/bash
    ssh-keygen -t ed25519 -C {{user}} -N {{password}} -f ~/.ssh/id_ed25519_{{key_postfix}}
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/id_ed25519_{{key_postfix}}
    pbcopy < ~/.ssh/id_ed25519_{{key_postfix}}
    echo "ssh key has been added to agent and copied to pasteboard. Now add it where needed"
