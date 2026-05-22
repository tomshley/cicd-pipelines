#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Mirror Poll: fetch branches from a remote and push them to local origin.
# Used for cron/scheduled-pipeline-driven reverse mirroring (when the source
# remote has no CI or push-driven mirroring is unavailable).
#
# Optional env vars (set by consumer):
#   TOMSHLEY_CICD_MIRROR_POLL_URL              — remote URL to fetch FROM
#   TOMSHLEY_CICD_MIRROR_POLL_BRANCH_PATTERNS  — comma-separated glob patterns
#   TOMSHLEY_CICD_MIRROR_POLL_PUSH_TOKEN       — token for pushing to origin
#   TOMSHLEY_CICD_MIRROR_POLL_PUSH_USER        — HTTPS auth username
#   TOMSHLEY_CICD_MIRROR_POLL_SSH_KEY          — SSH key for fetch
#   TOMSHLEY_CICD_MIRROR_POLL_DRY_RUN          — skip actual push (default: false)
#   TOMSHLEY_CICD_MIRROR_POLL_FORCE_PUSH       — use --force (default: false)
set -euo pipefail
if [ -n "${BASH_VERSION:-}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  SCRIPT_DIR="${TOMSHLEY_CICD_TOOLBOX_ROOT:-/opt/tomshley-cicd-pipelines-toolbox}/mirror"
fi
TOOLBOX_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$TOOLBOX_DIR/lib/log.sh"

: "${TOMSHLEY_CICD_MIRROR_POLL_URL:=}"
: "${TOMSHLEY_CICD_MIRROR_POLL_BRANCH_PATTERNS:=}"
: "${TOMSHLEY_CICD_MIRROR_POLL_PUSH_TOKEN:=}"
: "${TOMSHLEY_CICD_MIRROR_POLL_PUSH_USER:=oauth2}"
: "${TOMSHLEY_CICD_MIRROR_POLL_SSH_KEY:=}"
: "${TOMSHLEY_CICD_MIRROR_POLL_DRY_RUN:=false}"
: "${TOMSHLEY_CICD_MIRROR_POLL_FORCE_PUSH:=false}"

if [ -z "$TOMSHLEY_CICD_MIRROR_POLL_URL" ]; then
  echo "TOMSHLEY_CICD_MIRROR_POLL_URL is not set — skipping poll"
  exit 0
fi
if [ -z "$TOMSHLEY_CICD_MIRROR_POLL_BRANCH_PATTERNS" ]; then
  log_error "TOMSHLEY_CICD_MIRROR_POLL_BRANCH_PATTERNS must be set when polling"
  exit 1
fi

# SSH key setup (only for SSH URLs)
if [ -n "$TOMSHLEY_CICD_MIRROR_POLL_SSH_KEY" ]; then
  if [ ! -f "$TOMSHLEY_CICD_MIRROR_POLL_SSH_KEY" ]; then
    log_warn "TOMSHLEY_CICD_MIRROR_POLL_SSH_KEY is set to '$TOMSHLEY_CICD_MIRROR_POLL_SSH_KEY' but file not found — proceeding without SSH key (will fail if poll URL requires auth)"
  elif echo "$TOMSHLEY_CICD_MIRROR_POLL_URL" | grep -qE '^(git@|ssh://)'; then
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    touch ~/.ssh/known_hosts
    cp "$TOMSHLEY_CICD_MIRROR_POLL_SSH_KEY" ~/.ssh/poll_key
    chmod 600 ~/.ssh/poll_key
    POLL_HOST=$(echo "$TOMSHLEY_CICD_MIRROR_POLL_URL" | sed -E '
      s|^git@\[([^]]+)\]:.*|\1|;
      s|^git@([^:]+):.*|\1|;
      s|^ssh://([^@]+@)?\[([^]]+)\].*|\2|;
      s|^ssh://([^@]+@)?([^/:]+).*|\2|
    ')
    if [ -n "$POLL_HOST" ] && ! echo "$POLL_HOST" | grep -q '/'; then
      ssh-keyscan -H "$POLL_HOST" >> ~/.ssh/known_hosts 2>/dev/null || true
      export GIT_SSH_COMMAND="ssh -i ~/.ssh/poll_key -o StrictHostKeyChecking=accept-new"
    else
      log_warn "Could not derive SSH host from TOMSHLEY_CICD_MIRROR_POLL_URL — SSH key may be ignored by git"
    fi
  else
    log_warn "TOMSHLEY_CICD_MIRROR_POLL_SSH_KEY is set but POLL_URL is not SSH (git@/ssh://) — SSH key will be ignored"
  fi
fi

# Add poll remote
git remote add poll-remote "$TOMSHLEY_CICD_MIRROR_POLL_URL" 2>/dev/null \
  || git remote set-url poll-remote "$TOMSHLEY_CICD_MIRROR_POLL_URL"

SAFE_POLL_URL=$(echo "$TOMSHLEY_CICD_MIRROR_POLL_URL" | sed -E 's|://[^@]+@|://***@|')
echo "=== Mirror Poll ==="
echo "Poll URL:   $SAFE_POLL_URL"
echo "Patterns:   $TOMSHLEY_CICD_MIRROR_POLL_BRANCH_PATTERNS"
echo "Dry run:    $TOMSHLEY_CICD_MIRROR_POLL_DRY_RUN"
echo "Force push: $TOMSHLEY_CICD_MIRROR_POLL_FORCE_PUSH"

# Unset any inherited http.extraheader (e.g. from CI job auth) before fetching
# from poll-remote, so credentials intended for origin are not sent to the
# external poll URL.
git config --global --unset-all http.extraheader 2>/dev/null || true

# Fetch all branches from poll remote
git fetch poll-remote --prune

# Configure origin push URL with token if provided (HTTPS).
# Use shell parameter expansion rather than sed to safely handle tokens
# containing special characters (|, &, \, /, etc.) that would break sed.
if [ -n "$TOMSHLEY_CICD_MIRROR_POLL_PUSH_TOKEN" ]; then
  ORIGIN_URL=$(git remote get-url origin)
  case "$ORIGIN_URL" in
    https://*)
      # Strip any existing user:pass@ prefix, then prepend our credentials.
      URL_NOSCHEME="${ORIGIN_URL#https://}"
      URL_NOAUTH="${URL_NOSCHEME#*@}"
      # If there was no @, ${URL_NOSCHEME#*@} returns the original; guard that.
      case "$URL_NOSCHEME" in
        *@*) ;; # had auth, stripped
        *) URL_NOAUTH="$URL_NOSCHEME" ;;
      esac
      AUTHED_URL="https://${TOMSHLEY_CICD_MIRROR_POLL_PUSH_USER}:${TOMSHLEY_CICD_MIRROR_POLL_PUSH_TOKEN}@${URL_NOAUTH}"
      git remote set-url --push origin "$AUTHED_URL"
      ;;
  esac
fi

# Match poll-remote branches against patterns.
# Use full refname (not :short) and explicitly exclude the symbolic HEAD ref,
# so a literal branch named "HEAD" on the remote is not silently dropped.
MATCHED_BRANCHES=""
OLD_IFS="$IFS"
IFS=','
for pattern in $TOMSHLEY_CICD_MIRROR_POLL_BRANCH_PATTERNS; do
  pattern=$(echo "$pattern" | tr -d '[:space:]')
  while IFS= read -r refname; do
    case "$refname" in
      refs/remotes/poll-remote/HEAD) continue ;;
    esac
    branch="${refname#refs/remotes/poll-remote/}"
    case "$branch" in
      $pattern) MATCHED_BRANCHES="$MATCHED_BRANCHES $branch" ;;
    esac
  done < <(git for-each-ref --format='%(refname)' refs/remotes/poll-remote/)
done
IFS="$OLD_IFS"

# Disable pathname expansion: branch names may contain glob-like characters
# and we iterate $MATCHED_BRANCHES unquoted (word-splitting is intentional).
set -f

# Deduplicate (a branch may match multiple patterns).
if [ -n "$MATCHED_BRANCHES" ]; then
  MATCHED_BRANCHES=$(printf '%s\n' $MATCHED_BRANCHES | sort -u | tr '\n' ' ')
fi

PUSHED=0
FAILED=0

if [ "$TOMSHLEY_CICD_MIRROR_POLL_FORCE_PUSH" = "true" ]; then
  PUSH_FLAGS="--force"
else
  PUSH_FLAGS="--force-with-lease"
fi

for branch in $MATCHED_BRANCHES; do
  # Skip if origin already has the same SHA (no-op optimization)
  REMOTE_SHA=$(git rev-parse "poll-remote/$branch" 2>/dev/null || echo "")
  ORIGIN_SHA=$(git rev-parse "origin/$branch" 2>/dev/null || echo "")
  if [ -n "$REMOTE_SHA" ] && [ "$REMOTE_SHA" = "$ORIGIN_SHA" ]; then
    echo "Skipping branch: $branch (origin already at $REMOTE_SHA)"
    continue
  fi
  if [ "$TOMSHLEY_CICD_MIRROR_POLL_DRY_RUN" = "true" ]; then
    echo "[dry-run] Would push: poll-remote/$branch → origin/$branch"
    PUSHED=$((PUSHED + 1))
  else
    echo "Pushing branch: $branch (poll-remote → origin) ($PUSH_FLAGS)"
    if git push origin "refs/remotes/poll-remote/$branch:refs/heads/$branch" $PUSH_FLAGS; then
      PUSHED=$((PUSHED + 1))
    else
      log_error "Failed to push branch $branch to origin"
      FAILED=$((FAILED + 1))
    fi
  fi
done

if [ "$PUSHED" -gt 0 ]; then
  echo "[ok] Polled and processed $PUSHED branch(es) from $SAFE_POLL_URL"
else
  echo "No matching branches found"
fi

if [ "$FAILED" -gt 0 ]; then
  log_warn "$FAILED branch(es) failed to push (see errors above)"
fi

set +f
exit 0
