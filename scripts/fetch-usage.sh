#!/bin/bash
# Fetches unified rate limit utilization from Anthropic API response headers.
# Called via a Stop hook; caches results to ~/.claude/.usage-cache.json.
# Note: anthropic-ratelimit-unified-* headers are undocumented but power /usage.
# Requires: macOS keychain ("Claude Code-credentials"), curl, jq

CACHE_FILE="$HOME/.claude/.usage-cache.json"

TOKEN=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print(d['claudeAiOauth']['accessToken'])" 2>/dev/null)

[[ -z "$TOKEN" ]] && exit 0

HEADERS=$(curl -s -D - -o /dev/null \
  --max-time 10 \
  -H "Authorization: Bearer $TOKEN" \
  -H "anthropic-version: 2023-06-01" \
  -H "Content-Type: application/json" \
  -d '{"model":"claude-haiku-4-5","max_tokens":1,"messages":[{"role":"user","content":"hi"}]}' \
  "https://api.anthropic.com/v1/messages" 2>/dev/null)

util_5h=$(echo "$HEADERS" | grep -i "^anthropic-ratelimit-unified-5h-utilization:" | awk '{print $2}' | tr -d '\r')
util_7d=$(echo "$HEADERS" | grep -i "^anthropic-ratelimit-unified-7d-utilization:" | awk '{print $2}' | tr -d '\r')
reset_5h=$(echo "$HEADERS" | grep -i "^anthropic-ratelimit-unified-5h-reset:" | awk '{print $2}' | tr -d '\r')
reset_7d=$(echo "$HEADERS" | grep -i "^anthropic-ratelimit-unified-7d-reset:" | awk '{print $2}' | tr -d '\r')

[[ -z "$util_5h" || -z "$util_7d" ]] && exit 0

printf '{"util_5h":%s,"util_7d":%s,"reset_5h":%s,"reset_7d":%s,"fetched_at":%s}\n' \
  "$util_5h" "$util_7d" \
  "${reset_5h:-0}" "${reset_7d:-0}" \
  "$(date +%s)" > "$CACHE_FILE"
