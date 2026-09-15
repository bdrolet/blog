#!/usr/bin/env bash
# Poll the latest Cloudflare Pages deployment for the blog until it reaches a
# terminal stage, then print the result.
set -uo pipefail

PROJECT="${PAGES_PROJECT:-blog}"
TFVARS="${INFRA_TFVARS:-$HOME/src/infra/cloudflare/terraform.tfvars}"
MAX_WAIT="${MAX_WAIT:-900}"   # seconds

read_tfvar() {
  grep -E "^[[:space:]]*$1[[:space:]]*=" "$TFVARS" 2>/dev/null | sed 's/.*= *"//; s/".*//' | head -1
}

TOKEN="${CLOUDFLARE_API_TOKEN:-$(read_tfvar cloudflare_api_token)}"
ACCOUNT="${CLOUDFLARE_ACCOUNT_ID:-$(read_tfvar account_id)}"

if [ -z "$TOKEN" ] || [ -z "$ACCOUNT" ]; then
  echo "No Cloudflare credentials."
  echo "Expected CLOUDFLARE_API_TOKEN / CLOUDFLARE_ACCOUNT_ID in the environment,"
  echo "or cloudflare_api_token / account_id in ${TFVARS}."
  echo "Skip to the live-site check in SKILL.md, or read the build log in the dashboard."
  exit 2
fi

api() {
  curl -sS "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT}/pages/projects/${PROJECT}/deployments?per_page=1" \
    -H "Authorization: Bearer ${TOKEN}"
}

waited=0
while :; do
  out=$(api | python3 -c '
import sys, json
d = json.load(sys.stdin)
if not d.get("success"):
    print("api-error|" + json.dumps(d.get("errors")) + "||"); raise SystemExit
r = (d.get("result") or [{}])[0]
ls = r.get("latest_stage") or {}
print("|".join([
    str(ls.get("name")), str(ls.get("status")),
    str(r.get("url") or ""), str((r.get("id") or "")[:8]),
]))
' 2>/dev/null)

  IFS='|' read -r stage status url id <<< "$out"

  if [ "$stage" = "api-error" ]; then
    echo "Cloudflare API error: $status"
    exit 1
  fi

  case "$status" in
    success)
      if [ "$stage" = "deploy" ]; then
        echo "Deployment ${id}: deploy/success"
        echo "URL: ${url}"
        exit 0
      fi
      ;;
    failure|canceled|skipped)
      echo "Deployment ${id} FAILED at stage: ${stage}/${status}"
      echo "Build log: https://dash.cloudflare.com/?to=/:account/pages/view/${PROJECT}/${id}"
      exit 1
      ;;
  esac

  if [ "$waited" -ge "$MAX_WAIT" ]; then
    echo "Timed out after ${MAX_WAIT}s at stage ${stage}/${status} (deployment ${id})."
    exit 1
  fi

  echo "  ${stage}/${status} ... (${waited}s)"
  sleep 10
  waited=$((waited + 10))
done
