#!/bin/bash
input=$(cat)

GREEN='\033[32m'
YELLOW='\033[33m'
PURPLE='\033[35m'
WHITE='\033[37m'
RESET='\033[0m'

MODEL=$(echo "$input" | jq -r '.model.display_name')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
PROMPT=${WHITE}\$${RESET}
# Build progress bar: printf -v creates a run of spaces, then
# ${var// /▓} replaces each space with a block character
BAR_WIDTH=10
FILLED=$((PCT * BAR_WIDTH / 100))
EMPTY=$((BAR_WIDTH - FILLED))
BAR=""

# git status
DIR_COLORED="${YELLOW}~/${DIR##*/}${RESET}"
BRANCH_COLORED=""
GIT_STATUS=""
if git rev-parse --git-dir > /dev/null 2>&1; then
    BRANCH=$(git branch --show-current 2>/dev/null)
    # STAGED=$(git diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
    # MODIFIED=$(git diff --numstat 2>/dev/null | wc -l | tr -d ' ')

    BRANCH_COLORED="${PURPLE}${BRANCH}${RESET}"
    # [ "$STAGED" -gt 0 ] && GIT_STATUS="${GREEN}+${STAGED}${RESET}"
    # [ "$MODIFIED" -gt 0 ] && GIT_STATUS="${GIT_STATUS}${YELLOW}~${MODIFIED}${RESET}"
fi

[ "$FILLED" -gt 0 ] && printf -v FILL "%${FILLED}s" && BAR="${FILL// /▓}"
[ "$EMPTY" -gt 0 ] && printf -v PAD "%${EMPTY}s" && BAR="${BAR}${PAD// /░}"

echo -e "[$MODEL] $BAR ${PCT}% ${DIR_COLORED} ${BRANCH_COLORED}${PROMPT}"
