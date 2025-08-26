{ config, pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    completionInit = ''
      # initializes the Zsh completion system
      autoload -Uz compinit
      compinit

      # Load other completions
      source <(kubectl completion zsh)
      source <(docker completion zsh)
    '';
    autosuggestion.enable = true;
    syntaxHighlighting.enable = false;


    # goes into .zshrc
    shellAliases = {
      # Navigation shortcuts
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";

      "grep" = "grep --color=auto";

      "yaml-to-json" = "yq -P --output-format json $1;";
      "json-to-yaml" = "yq -P $1;";

      "docker-exec-bash" = "docker exec -it $1 /bin/bash;";
      "docker-run-bash" = "docker run -it $1 /bin/bash;";

      # Run a Docker container and forward all AWS environment variables
      "docker-run-with-aws-access" = ''
        docker run -it --env-file <(aws-vault exec $1 -- env | grep ^AWS_) $2
      '';

      # Remove all untagged images
      "docker-remove-none-images" = ''
          docker rmi -f $(docker images | grep '<none>' | sed  -E 's/[ ]+/,/g' | cut -f3 -d,)
      '';

    };

    # History settings
    history = {
      size = 10000;
      save = 10000;
      path = "${config.home.homeDirectory}/.zsh_history";
      ignoreAllDups = true;
      saveNoDups = true;
      findNoDups = true;
      ignoreSpace = true;
      expireDuplicatesFirst = true;
      share = true;
      extended = true;
      append = true;
    };

    # Goes into .zshrc
    initContent = ''
      # Ensure fzf is running
      source <(fzf --zsh)

      # direnv to use .envrc files in directories
      eval "$(direnv hook zsh)"

      # starship
      eval "$(starship init zsh)"
    '';

    # Goes into .zshenv
    envExtra = ''
      # GPG signing
      export GPG_TTY=$(tty)

      # Load secrets
      [ -s "$HOME/.zshenv.secrets" ] && source $HOME/.zshenv.secrets

      # starship
      export STARSHIP_CONFIG="$XDG_CONFIG_HOME/starship.toml"

      # asdf
      export ASDF_DATA_DIR="$HOME/.asdf/shims"
    '';

    plugins = [
      {
        name = "zinit";
        file = "zinit.zsh";
        src = pkgs.fetchFromGitHub {
          owner = "zdharma-continuum";
          repo = "zinit";
          rev = "v3.14.0";
          sha256 = "sha256-cBMGmFrveBes30aCSLMBO8WrtoPZeMNjcEQoQEzBNvM=";
        };
      }
    ];

  };
}
