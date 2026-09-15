#!/usr/bin/env bash
# Poll the Cloudflare Pages deployment for a given commit until it reaches a
# terminal stage, then print the result.
#
#   deploy-status.sh [commit-sha]     # defaults to HEAD
#
# Waits for the deployment to appear first — Cloudflare takes a few seconds to
# queue a build after a push, during which the most recent deployment is still
# the previous one.
set -uo pipefail

PROJECT="${PAGES_PROJECT:-blog}"
TFVARS="${INFRA_TFVARS:-$HOME/src/infra/cloudflare/terraform.tfvars}"
MAX_WAIT="${MAX_WAIT:-900}"   # seconds to wait for a build to finish
APPEAR_WAIT="${APPEAR_WAIT:-120}"  # seconds to wait for the build to be queued

COMMIT="${1:-$(git rev-parse HEAD 2>/dev/null)}"
if [ -z "$COMMIT" ]; then
  echo "No commit given and not in a git repo."
  exit 2
fi

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

# Print "stage|status|url|id" for the deployment built from $COMMIT, or
# "none||| " if no deployment for that commit exists yet.
lookup() {
  curl -sS "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT}/pages/projects/${PROJECT}/deployments?per_page=10" \
    -H "Authorization: Bearer ${TOKEN}" \
  | COMMIT="$COMMIT" python3 -c '
import sys, os, json
want = os.environ["COMMIT"]
try:
    d = json.load(sys.stdin)
except Exception:
    print("retry|||"); raise SystemExit
if not d.get("success"):
    print("api-error|" + json.dumps(d.get("errors")) + "||"); raise SystemExit
for r in d.get("result") or []:
    meta = (r.get("deployment_trigger") or {}).get("metadata") or {}
    if (meta.get("commit_hash") or "").startswith(want[:7]):
        ls = r.get("latest_stage") or {}
        print("|".join([str(ls.get("name")), str(ls.get("status")),
                        str(r.get("url") or ""), str((r.get("id") or "")[:8])]))
        raise SystemExit
print("none|||")
' 2>/dev/null
}

short="${COMMIT:0:7}"
echo "Waiting for the Pages build of ${short} ..."

waited=0
while :; do
  IFS='|' read -r stage status url id <<< "$(lookup)"

  case "$stage" in
    api-error)
      echo "Cloudflare API error: $status"
      exit 1
      ;;
    none|retry|"")
      if [ "$waited" -ge "$APPEAR_WAIT" ]; then
        echo "No deployment for ${short} appeared after ${APPEAR_WAIT}s."
        echo "Was the commit pushed to the production branch?"
        exit 1
      fi
      ;;
    *)
      case "$status" in
        success)
          if [ "$stage" = "deploy" ]; then
            echo "Deployment ${id} (${short}): deploy/success"
            echo "URL: ${url}"
            exit 0
          fi
          ;;
        failure|canceled|skipped)
          echo "Deployment ${id} (${short}) FAILED at stage: ${stage}/${status}"
          echo "Build log: https://dash.cloudflare.com/?to=/:account/pages/view/${PROJECT}/${id}"
          exit 1
          ;;
      esac
      echo "  ${stage}/${status} ... (${waited}s)"
      ;;
  esac

  if [ "$waited" -ge "$MAX_WAIT" ]; then
    echo "Timed out after ${MAX_WAIT}s (last seen: ${stage}/${status})."
    exit 1
  fi

  sleep 10
  waited=$((waited + 10))
done
