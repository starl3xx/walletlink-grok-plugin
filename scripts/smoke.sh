#!/usr/bin/env bash
# Smoke-tests the plugin against the live server.
#
# Three checks, cheapest first:
#   1. The manifest files parse and carry the fields the marketplace reads.
#   2. The MCP endpoint answers an initialize with a real serverInfo.
#   3. tools/list names every tool the skill documents.
#
# A keyed resolve runs only when WALLETLINK_API_KEY is set, so a fork's CI
# passes without a secret. Discovery is IP-rate-limited at the server (120 an
# hour), which a CI run that calls it three times does not approach.
set -euo pipefail

# Manifest paths are repo-relative, so run from the repo root wherever the
# script was invoked from.
cd "$(dirname "$0")/.."

MCP_URL="${MCP_URL:-https://walletlink.social/api/mcp}"
CURL=(curl -sS --max-time 30)

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

# --- 1. manifests -----------------------------------------------------------

jq -e '.name == "walletlink" and .version and .description and .license' \
  .grok-plugin/plugin.json > /dev/null || fail "plugin.json is missing a required field"

jq -e '.mcpServers.walletlink.type == "http"' .mcp.json > /dev/null \
  || fail ".mcp.json does not declare the http server"

CONFIGURED_URL="$(jq -r '.mcpServers.walletlink.url' .mcp.json)"
[ "$CONFIGURED_URL" = "https://walletlink.social/api/mcp" ] \
  || fail ".mcp.json points at $CONFIGURED_URL"

grep -q '^name: walletlink$' skills/walletlink/SKILL.md \
  || fail "SKILL.md frontmatter is missing its name"

echo "ok: manifests"

# --- 2. initialize ----------------------------------------------------------

# The server answers JSON or SSE depending on the client; accept both and
# capture the session id some transports issue. The assertion is on
# serverInfo, which only a successful initialize carries: a 401 challenge or
# an error body also mentions the walletlink.social domain, so the domain
# alone proves nothing.
HEADERS_FILE="$(mktemp)"
trap 'rm -f "$HEADERS_FILE"' EXIT
INIT_BODY='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"walletlink-grok-plugin-ci","version":"1.0.0"}}}'

INIT_RESPONSE="$("${CURL[@]}" -X POST "$MCP_URL" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -D "$HEADERS_FILE" \
  --data "$INIT_BODY")" || fail "initialize did not answer"

echo "$INIT_RESPONSE" | grep -q '"serverInfo"' \
  || fail "initialize answered without serverInfo: $INIT_RESPONSE"
echo "$INIT_RESPONSE" | grep -q 'walletlink.social' \
  || fail "initialize answered without the server name: $INIT_RESPONSE"

SESSION_ID="$(awk 'tolower($1) == "mcp-session-id:" {print $2}' "$HEADERS_FILE" | tr -d '\r')"

SESSION_HEADER=()
if [ -n "$SESSION_ID" ]; then
  SESSION_HEADER=(-H "mcp-session-id: $SESSION_ID")
fi

# The lifecycle notification the spec expects between initialize and normal
# operation. Not asserted on: the server accepts requests without it today,
# and this exists so the test keeps passing if that ever tightens.
"${CURL[@]}" -X POST "$MCP_URL" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  ${SESSION_HEADER[@]+"${SESSION_HEADER[@]}"} \
  --data '{"jsonrpc":"2.0","method":"notifications/initialized"}' > /dev/null || true

echo "ok: initialize"

# --- 3. tools/list ----------------------------------------------------------

LIST_RESPONSE="$("${CURL[@]}" -X POST "$MCP_URL" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  ${SESSION_HEADER[@]+"${SESSION_HEADER[@]}"} \
  --data '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}')" \
  || fail "tools/list did not answer"

for TOOL in \
  walletlink_resolve_wallets \
  walletlink_wallets_by_x_handle \
  walletlink_wallets_by_farcaster_username \
  walletlink_index_coverage \
  walletlink_account_balance
do
  echo "$LIST_RESPONSE" | grep -q "$TOOL" \
    || fail "tools/list is missing $TOOL"
done

echo "ok: tools/list names all five tools"

# --- 4. a keyed resolve, when a key is available ----------------------------

if [ -n "${WALLETLINK_API_KEY:-}" ]; then
  CALL_RESPONSE="$("${CURL[@]}" -X POST "$MCP_URL" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json, text/event-stream' \
    -H "Authorization: Bearer $WALLETLINK_API_KEY" \
    ${SESSION_HEADER[@]+"${SESSION_HEADER[@]}"} \
    --data '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"walletlink_resolve_wallets","arguments":{"addresses":["0xd8da6bf26964af9d7eed9e03e53415d37aa96045"]}}}')" \
    || fail "keyed resolve did not answer"

  echo "$CALL_RESPONSE" | grep -q 'billed_matches' \
    || fail "keyed resolve answered without billing metadata: $CALL_RESPONSE"
  echo "ok: keyed resolve"
else
  echo "skip: keyed resolve (WALLETLINK_API_KEY not set)"
fi

echo "smoke ok"
