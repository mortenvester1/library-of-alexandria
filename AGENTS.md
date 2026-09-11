# AGENTS.md

Workstation setup: stow-managed dotfiles, package manifests, self-hosted apps, and knowledge-base wikis, installed and upgraded with `install.sh`.

Refer to the user as the Chief Librarian.

## Project map

- `dotfiles/` - one stow package per directory; `dotfiles/<pkg>/.config/...` mirrors `$HOME`
- `dotfiles/common/skills/` - the skillshare skill collection shared by every agent
- `pkgs/` - package manifests consumed by `install.sh` (apt, dnf, flatpak, homebrew)
- `apps/` - self-hosted services, one directory each
- `cron/` - scheduled scripts
- `library/` - knowledge-base wikis, one per directory (`library/AGENTS.md` for the conventions)
- `install.sh`, `justfile` - install and maintenance entry points

<important if="you need to install, restow, or upgrade this repo on the machine">

| Command                                           | What it does                                              |
| ------------------------------------------------- | --------------------------------------------------------- |
| `just --list`                                     | List all available targets                                |
| `just stow <pkg>...`                              | Restow one or more dotfiles packages into `$HOME`         |
| `just upgrade`                                    | Re-run `install.sh` against the local repo (`SKIP_GIT=1`) |
| `just create-gitlocal <email> <gpg-key>`          | Write `.gitlocal` and restow git                          |
| `just create-ssh-key <user> <postfix> [password]` | Generate an ed25519 key and add it to the agent           |
| `just copy-ssh-key <user> <host> <pub-key>`       | Install a public key on a remote host                     |
| `just create-ssh-config <postfix>`                | Write `~/.ssh/config` with a GitHub entry                 |
| `just create-gpg-key <name> <email> <password>`   | Generate a signing key and print the armored export       |
| `just dev-ubuntu-build`                           | Build the Ubuntu container used to test `install.sh`      |
| `just dev-ubuntu-install`                         | Run `install.sh` inside that container                    |

</important>

<important if="you are editing anything under dotfiles/">

- Edit the file in the repo, never its counterpart in `$HOME` - those are stow symlinks pointing back here.
- A newly added file is not live until `just stow <pkg>` runs; changes to an already-stowed file are.
</important>

<important if="you are adding or changing a skill">

- Source of truth is `dotfiles/common/skills/<name>/SKILL.md`. `dotfiles/common/skills/local/` is gitignored - machine-local skills that still sync everywhere.
- Never edit `~/.claude/skills` or `~/.agents/skills`; they are skillshare symlinks into this repo. Edit the source, then run `skillshare sync`.
- `skillshare sync` reads `~/.config/skillshare/config.yaml`, which only exists once the skillshare package is stowed.
</important>

<important if="you are working in library/">

- The wikis are symlinks into an iCloud Obsidian vault, so edits leave this repo. Read the wiki's own `AGENTS.md` before changing anything in one.
</important>
