#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

worker_type="$1"; shift
command_str="$*"

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export HOME="${HOME:-$PWD}"
export WORKTREE="${WORKTREE:?missing WORKTREE}"
export TASK_BRANCH="${TASK_BRANCH:-}"
export REPO_ROOT="${REPO_ROOT:-}"
export TASK_TYPE="$worker_type"

if forbidden_git_pattern "$command_str"; then
  echo "FORBIDDEN: merge / force-push / direct main/master operations are blocked" >&2
  exit 1
fi

case "$worker_type" in
  review|qa|research)
    if [[ "$command_str" == *"git commit"* || "$command_str" == *"git push"* ]]; then
      echo "FORBIDDEN: $worker_type worker cannot commit or push" >&2
      exit 1
    fi
    ;;
  doc)
    if [[ "$command_str" == *".py"* || "$command_str" == *".ts"* || "$command_str" == *".tsx"* || "$command_str" == *".js"* ]]; then
      echo "WARN: doc worker command mentions source code paths; review scope carefully" >&2
    fi
    ;;
  code)
    ;;
  *)
    echo "Unknown worker type: $worker_type" >&2
    exit 1
    ;;
esac

if [[ -n "$REPO_ROOT" ]]; then
  pybin="$(repo_venv_python "$REPO_ROOT" || true)"
  if [[ -n "$pybin" ]]; then
    export TD_PYTHON="$pybin"
    export VIRTUAL_ENV="$(cd "$(dirname "$pybin")/.." && pwd)"
    export PATH="$(dirname "$pybin"):$PATH"
  fi
fi

cd "$WORKTREE"
exec bash -lc "$command_str"
