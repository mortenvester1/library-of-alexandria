# Library of Alexandria

This repo is my personal library of everything.

## Repo structure

Below is a list of the most important files and directories in the repo.

```text
library-of-alexandria/
├── apps/              # Self-hosted services, one directory per service
│   └── entrance/      # An application gateway for accessing self-hosted services
├── cron/              # Contains various cronjobs
├── dotfiles/          # Configuration files of software (managed via stow)
│   ├── asdf/          # default tools managed with asdf
│   ├── claude/        # default configuration of claude code
│   ├── codex/         # codex configuration
│   ├── common/        # config shared across agents, incl. the skill collection
│   ├── ghostty/       # ghostty terminal configuration
│   ├── git/           # git configuration
│   ├── gnupg/         # gnupg configuration
│   ├── k9s/           # k9s configuration
│   ├── omp/           # oh-my-posh configuration
│   ├── opencode/      # opencode configuration
│   ├── skillshare/    # skillshare configuration (syncs skills to every agent)
│   ├── sql-formatter/ # sql-formatter configuration
│   ├── starship/      # starship / shell prompt configuration
│   ├── vim/           # vim configuration
│   ├── zed/           # zed configuration
│   └── zsh/           # zsh startup files
├── pkgs/              # Package manifests consumed by install.sh
│   ├── apt/           # Ubuntu packages
│   ├── dnf/           # Fedora packages and repo setup
│   ├── flatpak/       # Flatpak packages
│   └── homebrew/      # Brewfiles for macOS
├── library/           # Personal knowledge base wikis (see below)
├── install.sh         # script to install / upgrade the repo contents on machine
└── justfile           # install and maintenance targets (just --list)
```

## Skills

Agent skills live in `dotfiles/common/skills/` and are the single source of truth for every agent. [skillshare](https://github.com/runkids/skillshare) syncs them to `~/.claude/skills` (Claude Code) and `~/.agents/skills` (codex, opencode, omp) as symlinks, so the synced copies must never be edited directly — edit the source and run `skillshare sync`.

```text
dotfiles/common/skills/
├── <name>/SKILL.md        # tracked, shared across machines
└── local/<name>/SKILL.md  # gitignored, machine-local, still synced to every agent
```

`skillshare sync` reads `${XDG_CONFIG_HOME}/skillshare/config.yaml`, which is stowed from `dotfiles/skillshare/`. Two `justfile`-adjacent shell functions handle repo-scoped skills: `skillshare-init-project` and `skillshare-bridge` (see `dotfiles/zsh/.config/zsh/aliases.zsh`).

## Library

`library/` contains personal knowledge base wikis maintained by an LLM. The idea is based on [this pattern by Andrej Karpathy](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f): instead of RAG (re-deriving answers from raw documents on every query), the LLM incrementally builds and maintains a structured wiki that compounds knowledge over time.

Each wiki lives at `library/<name>/` and follows this structure:

```text
<wiki-name>/
├── AGENTS.md   # Schema and workflow instructions for the LLM
├── CLAUDE.md   # symlink to AGENTS.md
├── raw/        # Immutable source documents — never modified
│   └── index.md
└── wiki/       # LLM-maintained pages
    ├── index.md
    └── log.md
```

**Operations** (agent skills, invoked as slash commands in Claude Code):

| Command                         | Description                                                |
| ------------------------------- | ---------------------------------------------------------- |
| `/wiki-list`                    | List all available wikis                                   |
| `/wiki-ingest <wiki> <source>`  | Ingest a new source into a wiki                            |
| `/wiki-query <wiki> <question>` | Query a wiki and synthesize an answer                      |
| `/wiki-lint <wiki>`             | Health-check a wiki for contradictions, orphans, and gaps  |
| `/wiki-move <wiki>`             | Moves a wiki to the `$LLM_WIKIS_DIR` and creates a symlink |

## Install

The install requires bash, curl, git, sudo to be installed on your system. Run the [install.sh](./install.sh) script using curl

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/mortenvester1/library-of-alexandria/refs/heads/main/install.sh)"
```

After initial install, overrides and additional tool installations can be configured in the following files. Simply rerun the install script for the overrides to take effect.

```sh
${XDG_CONFIG_HOME}/asdf/.tool-versions.local
${XDG_CONFIG_HOME}/git/.gitlocal

${XDG_CONFIG_HOME}/zsh/.zshrc.local
${XDG_CONFIG_HOME}/zsh/.zshenv.local
${XDG_CONFIG_HOME}/zsh/.zshprofile.local
```

## Development

To test local changes to the install script, run it from the working copy:

```sh
/bin/bash -c "$(curl -fsSL file:///$(pwd)/install.sh)"
```

or

```sh
just upgrade
```

## References

- [XDG Base Directories](https://specifications.freedesktop.org/basedir-spec/latest/)

## Guides

- [Generate SSH keys](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)
- [Generate GPG Keys](https://docs.github.com/en/authentication/managing-commit-signature-verification/generating-a-new-gpg-key)
- [Gnu Stow](https://tamerlan.dev/how-i-manage-my-dotfiles-using-gnu-stow/)

### Raspberry pi

- [Pi NAS](https://www.raspberrypi.com/tutorials/nas-box-raspberry-pi-tutorial/)
- [Pi Hole](https://www.raspberrypi.com/tutorials/running-pi-hole-on-a-raspberry-pi/)
- [transmission](https://pimylifeup.com/raspberry-pi-transmission/)

### Media Server

- [Minidlna](https://bbrks.me/rpi-minidlna-media-server/)
- [Tdarr](https://docs.tdarr.io/docs/welcome/what)
- [Jellyfin](https://itsfoss.com/jellyfin-raspberry-pi/)

## zsh

- [zsh startup files](https://zsh.sourceforge.io/Doc/Release/Files.html)
- [zsh completion guide](https://thevaluable.dev/zsh-completion-guide-examples/)
- [zinit gallery](https://zdharma-continuum.github.io/zinit/wiki/GALLERY/#plugins)

## Jetson

- [Jetson Lab](https://www.jetson-ai-lab.com/)
- [Supported models](https://www.jetson-ai-lab.com/models/)
