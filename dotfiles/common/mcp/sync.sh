#!/usr/bin/env bash
# Render servers.json (+ the gitignored servers.local.json) into every agent
# framework's MCP config.
#
# Non-secret values (url, extra headers) are expanded from the environment here,
# because only claude/opencode interpolate env vars in those fields. Bearer
# tokens are never read — each target gets an env var *name* in its own syntax.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "${HERE}/../../.." && pwd)"
SRC="${HERE}/servers.json"
SRC_LOCAL="${HERE}/servers.local.json"

CLAUDE_CFG="${HOME}/.claude.json"
OMP_CFG="${REPO}/dotfiles/omp/.config/omp/agent/mcp.json"
OPENCODE_CFG="${REPO}/dotfiles/opencode/.config/opencode/opencode.local.json"
CODEX_CFG="${REPO}/dotfiles/codex/.codex/local.config.toml"

sources=()
[[ -f "${SRC}" ]] && sources+=("${SRC}")
[[ -f "${SRC_LOCAL}" ]] && sources+=("${SRC_LOCAL}")
if [[ ${#sources[@]} -eq 0 ]]; then
  echo "no source: expected ${SRC} and/or ${SRC_LOCAL}" >&2
  exit 1
fi

# servers.local.json wins per field, so it can override one url without
# restating the whole server.
merged="$(jq -s 'reduce .[] as $s ({}; . * ($s.servers // {})) | {servers: .}' "${sources[@]}")"

incomplete="$(jq -r '.servers
  | with_entries(select((.value.url // "") == "" or (.value.bearer_token_env // "") == ""))
  | keys | join(" ")' <<<"${merged}")"
if [[ -n "${incomplete}" ]]; then
  echo "servers missing url or bearer_token_env: ${incomplete}" >&2
  exit 1
fi

# Expand ${VAR} in url + headers, tagging unset ones so we can fail loudly.
resolved="$(jq '
  def expand:
    gsub("\\$\\{(?<v>[A-Za-z_][A-Za-z0-9_]*)\\}";
         if (env[.v] // "") == "" then "@@UNSET@@\(.v)" else env[.v] end);
  .servers
  | with_entries(
      .value.url |= expand
      | .value.headers //= {}
      | .value.headers |= with_entries(.value |= expand))
' <<<"${merged}")"

missing="$(jq -r '
  [ .. | strings | select(startswith("@@UNSET@@")) | ltrimstr("@@UNSET@@") ]
  | unique | join(" ")' <<<"${resolved}")"
if [[ -n "${missing}" ]]; then
  echo "unset environment variables: ${missing}" >&2
  exit 1
fi

names="$(jq -r 'keys_unsorted[]' <<<"${resolved}")"
want="$(jq -c 'keys' <<<"${resolved}")"

# Refuse to clobber a hand-added server in a file we render wholesale.
assert_only_managed() {
  local file="$1" path="$2" extra
  [[ -f "${file}" ]] || return 0
  extra="$(jq -r --argjson want "${want}" \
    "((${path}) // {} | keys) - \$want | join(\" \")" "${file}" 2>/dev/null || true)"
  [[ -n "${extra}" ]] || return 0
  echo "${file} has unmanaged servers: ${extra}" >&2
  if [[ "${MCP_SYNC_FORCE:-0}" != "1" ]]; then
    echo "add them to ${SRC_LOCAL}, or re-run with MCP_SYNC_FORCE=1 to drop them" >&2
    exit 1
  fi
}

write_atomic() { local dest="$1"; cat >"${dest}.tmp" && mv "${dest}.tmp" "${dest}"; }

# claude — merge only; the file also holds project and session state.
[[ -f "${CLAUDE_CFG}" ]] || echo '{}' >"${CLAUDE_CFG}"
jq --argjson servers "${resolved}" '
  .mcpServers = (.mcpServers // {}) + ($servers | with_entries(.value = {
    type: "http",
    url: .value.url,
    headers: ({ "Authorization": "Bearer ${\(.value.bearer_token_env)}" } + .value.headers)
  }))
' "${CLAUDE_CFG}" | write_atomic "${CLAUDE_CFG}"

assert_only_managed "${OMP_CFG}" '.mcpServers'
jq -n --argjson servers "${resolved}" '{
  "$schema": "https://raw.githubusercontent.com/can1357/oh-my-pi/main/packages/coding-agent/src/config/mcp-schema.json",
  mcpServers: ($servers | with_entries(.value = {
    type: "http",
    url: .value.url,
    headers: ({ "Authorization": "Bearer ${\(.value.bearer_token_env)}" } + .value.headers)
  }))
}' | write_atomic "${OMP_CFG}"

assert_only_managed "${OPENCODE_CFG}" '.mcp'
jq -n --argjson servers "${resolved}" '{
  "$schema": "https://opencode.ai/config.json",
  mcp: ($servers | with_entries(.value = {
    type: "remote",
    url: .value.url,
    enabled: true,
    headers: ({ "Authorization": "Bearer {env:\(.value.bearer_token_env)}" } + .value.headers)
  }))
}' | write_atomic "${OPENCODE_CFG}"

# codex — TOML, and the only target taking the token as a bare env var name.
while read -r name; do
  jq -r --arg n "${name}" '
    .[$n] as $s
    | "[mcp_servers.\($n)]",
      "url = \($s.url | tojson)",
      "bearer_token_env_var = \($s.bearer_token_env | tojson)",
      (if ($s.headers | length) > 0 then
         "", "[mcp_servers.\($n).http_headers]",
         ($s.headers | to_entries[] | "\(.key | tojson) = \(.value | tojson)")
       else empty end),
      ""
  ' <<<"${resolved}"
done <<<"${names}" | write_atomic "${CODEX_CFG}"

echo "synced $(tr '\n' ' ' <<<"${names}")into:"
echo "  ${CLAUDE_CFG} (merged)"
echo "  ${OMP_CFG}"
echo "  ${OPENCODE_CFG}"
echo "  ${CODEX_CFG}"
echo "note: a running Claude Code session rewrites ~/.claude.json on exit — restart it to pick this up"
