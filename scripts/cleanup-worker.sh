#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

[[ $# -eq 1 ]] || { echo "Usage: cleanup-worker.sh <task-id>" >&2; exit 1; }
task_id="$1"
task_json="$(get_task "$task_id")"
[[ -n "$task_json" ]] || { echo "Task not found: $task_id" >&2; exit 1; }

status=$(jq -r '.status' <<<"$task_json")
session=$(jq -r '.session' <<<"$task_json")
worktree=$(jq -r '.worktree' <<<"$task_json")
repo=$(jq -r '.repo // ""' <<<"$task_json")
branch=$(jq -r '.branch // ""' <<<"$task_json")
created_git_worktree=$(jq -r '.createdGitWorktree // false' <<<"$task_json")
pid_file="$PID_DIR/$task_id.pid"

case "$status" in merged|closed|cancelled|failed|done) ;; *) echo "Refusing cleanup: task status is $status" >&2; exit 1 ;; esac
if tmux has-session -t "$session" 2>/dev/null; then tmux kill-session -t "$session"; fi
if [[ -f "$pid_file" ]]; then kill "$(cat "$pid_file")" 2>/dev/null || true; rm -f "$pid_file"; fi
if [[ "$created_git_worktree" == "true" && -n "$repo" && -n "$branch" ]]; then
  git -C "$repo" worktree remove "$worktree" --force >/dev/null 2>&1 || rm -rf "$worktree"
  git -C "$repo" branch -D "$branch" >/dev/null 2>&1 || true
else
  rm -rf "$worktree"
fi
remove_task "$task_id"
echo "cleaned: $task_id"
