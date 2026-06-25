#!/bin/bash
input=$(cat)

CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
PURPLE='\033[35m'
WHITE='\033[37m'
RED='\033[38'
RESET='\033[0m'

MODEL=$(echo "$input" | jq -r '.model.display_name')
EFFORT_LEVEL=$(echo "$input" | jq -r '.effort.level // empty')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
CTX_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)

SIMPLE_HOST=$(hostname | cut -f1 -d.)
DIR_COLORED="${YELLOW}~/${DIR##*/}${RESET}"
USER_COLORED="${CYAN}${USER}${RESET}"
HOST_COLORED="${GREEN}${SIMPLE_HOST}${RESET}"

RL_5H_PCT=$(echo "$input"      | jq -r '.rate_limits.five_hour.used_percentage // empty' | cut -d. -f1)
RL_7D_PCT=$(echo "$input"     | jq -r '.rate_limits.seven_day.used_percentage // empty' | cut -d. -f1)
RL_RESETS_5H_TS=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
RL_RESETS_5H=""
if [ -n "$RL_RESETS_5H_TS" ]; then
  DIFF=$(( RL_RESETS_5H_TS - $(date +%s) ))
  [ "$DIFF" -lt 0 ] && DIFF=0
  RL_RESETS_5H=$(printf "%dH%2dM" $(( DIFF / 3600 )) $(( (DIFF % 3600) / 60 )))
fi
# RL_RESETS_7D_TS=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
CACHE_READ=$(echo "$input"     | jq -r '.context_window.current_usage.cache_read_input_tokens // empty')
CACHE_CREATE=$(echo "$input"   | jq -r '.context_window.current_usage.cache_creation_input_tokens // empty')


PROMPT=${WHITE}\$${RESET}
# Build progress bar: printf -v creates a run of spaces, then
# ${var// /▓} replaces each space with a block character
BAR_WIDTH=10
CTX_FILLED=$((CTX_PCT * BAR_WIDTH / 100))
CTX_EMPTY=$((BAR_WIDTH - CTX_FILLED))
CTX_BAR=""

RL_5H_FILLED=$((RL_5H_PCT * BAR_WIDTH / 100))
RL_5H_EMPTY=$((BAR_WIDTH - RL_5H_FILLED))
RL_5H_BAR=""

RL_7D_FILLED=$((RL_7D_PCT * BAR_WIDTH / 100))
RL_7D_EMPTY=$((BAR_WIDTH - RL_7D_FILLED))
RL_7D_BAR=""

CACHE_STR=""
CACHE_TOTAL=$(( ${CACHE_READ:-0} + ${CACHE_CREATE:-0} ))
if [ "$CACHE_TOTAL" -gt 0 ] 2>/dev/null; then
  CACHE_HIT_PCT=$(( CACHE_READ * 100 / CACHE_TOTAL ))
  if [ "$CACHE_HIT_PCT" -ge 80 ]; then
    CACHE_COLOR="${GREEN}"
  elif [ "$CACHE_HIT_PCT" -ge 50 ]; then
    CACHE_COLOR="${YELLOW}"
  else
    CACHE_COLOR="${RED}"
  fi
  CACHE_STR="| cache: ${CACHE_COLOR}${CACHE_HIT_PCT}%${RESET}"
fi

# git status
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

[ "$CTX_FILLED" -gt 0 ] && printf -v FILL "%${CTX_FILLED}s" && CTX_BAR="${FILL// /▓}"
[ "$CTX_EMPTY" -gt 0 ] && printf -v PAD "%${CTX_EMPTY}s" && CTX_BAR="${CTX_BAR}${PAD// /░}"

[ "$RL_5H_FILLED" -gt 0 ] && printf -v FILL "%${RL_5H_FILLED}s" && RL_5H_BAR="${FILL// /▓}"
[ "$RL_5H_EMPTY" -gt 0 ] && printf -v PAD "%${RL_5H_EMPTY}s" && RL_5H_BAR="${RL_5H_BAR}${PAD// /░}"

[ "$RL_7D_FILLED" -gt 0 ] && printf -v FILL "%${RL_7D_FILLED}s" && RL_7D_BAR="${FILL// /▓}"
[ "$RL_7D_EMPTY" -gt 0 ] && printf -v PAD "%${RL_7D_EMPTY}s" && RL_7D_BAR="${RL_7D_BAR}${PAD// /░}"

CTX_STR="ctx: ${CTX_BAR} ${CTX_PCT}%"
RL_5H_STR="| 5h: ${RL_5H_BAR} ${RL_5H_PCT:-0}%${RL_RESETS_5H:+ (${RL_RESETS_5H})}"
RL_7D_STR="| 7d: ${RL_7D_BAR} ${RL_7D_PCT:-0}%"

echo -e "[$MODEL:$EFFORT_LEVEL] ${CTX_STR} ${RL_5H_STR} ${RL_7D_STR} ${CACHE_STR}"
echo -e "${USER_COLORED}${WHITE}@${RESET}${HOST_COLORED}${WHITE}:${RESET}${DIR_COLORED} ${BRANCH_COLORED}${PROMPT}"
