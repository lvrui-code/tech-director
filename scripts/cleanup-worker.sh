#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

[[ $# -eq 1 ]] || { echo "Usage: cleanup-worker.sh <task-id>" >&2; exit 1; }
task_id="$1"
task_json="$(get_task "$task_id")"
[[ -n "$task_json" ]] || { echo "Task not found: $task_id" >&2; exit 1; }

session=$(jq -r '.session' <<<"$task_json")
worktree=$(jq -r '.worktree' <<<"$task_json")
pid_file="$PID_DIR/$task_id.pid"

if tmux has-session -t "$session" 2>/dev/null; then
  tmux kill-session -t "$session"
fi
if [[ -f "$pid_file" ]]; then
  pid=$(cat "$pid_file")
  kill "$pid" 2>/dev/null || true
  rm -f "$pid_file"
fi
rm -rf "$worktree"
remove_task "$task_id"
echo "cleaned: $task_id"
