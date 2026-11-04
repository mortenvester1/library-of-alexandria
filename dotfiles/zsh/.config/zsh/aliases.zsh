#!/bin/zsh
# following https://www.thorsten-hans.com/5-types-of-zsh-aliases

# OS dependent
# homebrew - add to path (precedence over system installs)
# Set Brewfile destination
# Set LS_COLORS
if [[ "$(uname)" == "Darwin" ]]
then
  alias ls="gls --color -alh --group-directories-first"
elif [[ "$(uname)" == "Linux" ]]
then
  alias ls="ls --color -alh --group-directories-first"
fi

# Simple aliases
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."

# To support migration to prek over pre-commit
alias pre-commit="prek"


# Claude Code - auto-load machine-local settings unless --settings is already passed
claude() {
  local has_settings=0
  for arg in "$@"; do
    case "$arg" in
      --settings|--settings=*) has_settings=1 ;;
    esac
  done
  # claude errors out if --settings points at a file that doesn't exist
  if (( has_settings )) || [[ ! -f "$HOME/.claude/settings.local.json" ]]; then
    command claude "$@"
  else
    command claude --settings "$HOME/.claude/settings.local.json" "$@"
  fi
}

# codex - auto-load local profile unless --profile is already passed
codex() {
  local has_profile=0
  for arg in "$@"; do
    case "$arg" in
      --profile|--profile=*|-p) has_profile=1 ;;
    esac
  done
  if (( has_profile )); then
    command codex "$@"
  else
    command codex --profile local "$@"
  fi
}

# use gnu ls instad
alias activate-venv="source .venv/bin/activate"

# Functions

# Docker - connect to a running container and start a bash session
docker-exec-bash() {
  docker exec -it $1 /bin/bash;
};

# Docker - Start Docker container and connect to it in bash session
docker-run-bash() {
  docker run -it $1 /bin/bash;
};

# Docker - Run a Docker container and forward all AWS environment variables
docker-run-with-aws-access(){
  docker run -it --env-file <(aws-vault exec $1 -- env | grep ^AWS_) $2
}

# Docker -  Remove all untagged images
docker-remove-none-images(){
    docker rmi -f $(docker images | grep '<none>' | sed  -E 's/[ ]+/,/g' | cut -f3 -d,)
}
# Claude Code with local LM Studio model. Usage: claude-local <model-name>
claude-local() {
  ANTHROPIC_BASE_URL="http://localhost:1234" claude --model "$1"
}

# json <-> yaml conversion
yaml-to-json() {
	yq -P --output-format json $1
}
json-to-yaml() {
	yq -P $1
}
json-minify() {
	jq --compact-output < $1
}
json-maxify() {
	# uses two spaces by default
	jq < $1
}

# zinit update
zinit-update() {
  echo "Updating Zinit and plugins..."
  zinit self-update && zinit update --all
  echo "All Zinit plugins updated!"
}

# check login vs interactive - just for fun/learning
is-login-shell() {
	[[ -o login ]] && echo 'login' || echo 'non-login'
}
is-interactive-shell() {
	[[ $- == *i* ]] && echo 'interactive' || echo 'non-interactive'
}

# k9s
k9s-toogle-readonly() {
  CTX=$(kubectl config current-context)
  CLUSTER=$(kubectl config view --minify -o jsonpath='{.contexts[0].context.cluster}' | sed 's/[^a-zA-Z0-9]/-/g')
  yq -i '.k9s.readOnly |= not ' ${XDG_DATA_HOME}/k9s/clusters/${CLUSTER}/${CTX}/config.yaml
}

# reset zsh completions
zsh-completion-reset() {
  [ -s "${ZSH_COMPDUMP}" ] && rm ${ZSH_COMPDUMP}
}

# Jetson
jetson-toggle-desktop-gui() {
  sudo systemctl set-default multi-user.target
  sudo reboot
};

# skillshare - init project-level skills (.skillshare/skills -> .claude/skills + .agents/skills) and sync
skillshare-init-project() {
  skillshare init -p --targets claude,universal && skillshare sync -p
}

# skillshare - expose a repo's tracked .claude/skills to codex/omp via untracked symlinks in .agents/skills
# (local-only: links are git-excluded, existing .agents/skills entries are left alone)
skillshare-bridge() {
  local repo="${1:-$(git rev-parse --show-toplevel 2>/dev/null)}"
  [[ -d "${repo}/.claude/skills" ]] || { echo "no .claude/skills in ${repo:-<cwd>}" >&2; return 1; }
  local gitdir; gitdir="$(git -C "${repo}" rev-parse --git-common-dir)" || return 1
  [[ "${gitdir}" = /* ]] || gitdir="${repo}/${gitdir}"
  grep -qxF '.agents/skills/*' "${gitdir}/info/exclude" 2>/dev/null || echo '.agents/skills/*' >> "${gitdir}/info/exclude"
  # an empty SKILLSHARE_CONFIG silently falls back to the global config, so bail if mktemp fails
  local tmp; tmp="$(mktemp -d)" || return 1
  cat > "${tmp}/config.yaml" <<CFG
sources:
  skills: ${repo}/.claude/skills
mode: merge
target_naming: standard
targets:
  universal:
    skills:
      path: ${repo}/.agents/skills
CFG
  SKILLSHARE_CONFIG="${tmp}/config.yaml" skillshare sync
  local rc=$?
  rm -rf "${tmp}"
  return ${rc}
}

# zmv - lowercase every name in the cwd. Extra args (e.g. -n) are passed to zmv
lowercase() {
  zmv "$@" '(*)' '${(L)f}'
}

# zmv - strip a literal substring from every name in the cwd. Usage: replace <substring> [zmv-opts]
replace() {
  local pat="$1"
  [[ -n "${pat}" ]] || { print -u2 'usage: replace <substring> [zmv-options]'; return 1 }
  shift
  # (b) quotes glob metacharacters so the input is matched literally
  zmv "$@" "(*)${(b)pat}(*)" '$1$2'
}
