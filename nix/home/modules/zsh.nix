{ config, pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    enableAutosuggestions = true;
    enableCompletion = true;

    # goes into .zshrc
    shellAliases = {
      # Navigation shortcuts
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";

      "grep" = "grep --color=auto";
    };

    # History settings
    history = {
      size = 10000;
      save = 10000;
      path = "${config.home.homeDirectory}/.zsh_history";
      ignoreDups = true;
      ignoreSpace = true;
      expireDuplicatesFirst = true;
      share = true;
      extended = true;
    };

    # ZSH options via setopt XXX
    setOptions = [
      "APPEND_HISTORY"
      "SHARE_HISTORY"
      "HIST_IGNORE_SPACE"
      "HIST_IGNORE_ALL_DUPS"
      "HIST_SAVE_NO_DUPS"
      "HIST_IGNORE_DUPS"
      "HIST_FIND_NO_DUPS"
    ];

    initExtra = ''
      # Ensure fzf is running
      source <(fzf --zsh)
    ''

    # Goes into .zshenv
    envExtra = ''
      # Load secrets
      [ -s "$HOME/.zshenv.secrets" ] && source $HOME/.zshenv.secrets

      # GPG signing
      export GPG_TTY=$(tty)
    '';
  };
}
