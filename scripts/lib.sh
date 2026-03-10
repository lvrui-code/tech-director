#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="$PROJECT_ROOT/.openclaw-master"
TASKS_FILE="$STATE_DIR/active-tasks.json"
LOG_DIR="$STATE_DIR/logs"
REPORT_DIR="$STATE_DIR/reports"
WORKTREE_DIR="$STATE_DIR/worktrees"
PID_DIR="$STATE_DIR/pids"

mkdir -p "$STATE_DIR" "$LOG_DIR" "$REPORT_DIR" "$WORKTREE_DIR" "$PID_DIR"
[[ -f "$TASKS_FILE" ]] || printf '{"tasks":[]}
' > "$TASKS_FILE"

now_iso() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

has_tmux() {
  command -v tmux >/dev/null 2>&1
}

sanitize_name() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g'
}

update_task() {
  local task_id="$1"
  local patch="$2"
  local tmp
  tmp=$(mktemp)
  jq --arg task_id "$task_id" --argjson patch "$patch" '
    .tasks = (.tasks | map(if .taskId == $task_id then . + $patch else . end))
  ' "$TASKS_FILE" > "$tmp"
  mv "$tmp" "$TASKS_FILE"
}

append_task() {
  local task_json="$1"
  local tmp
  tmp=$(mktemp)
  jq --argjson task "$task_json" '.tasks += [$task]' "$TASKS_FILE" > "$tmp"
  mv "$tmp" "$TASKS_FILE"
}

remove_task() {
  local task_id="$1"
  local tmp
  tmp=$(mktemp)
  jq --arg task_id "$task_id" '.tasks |= map(select(.taskId != $task_id))' "$TASKS_FILE" > "$tmp"
  mv "$tmp" "$TASKS_FILE"
}

get_task() {
  local task_id="$1"
  jq --arg task_id "$task_id" -c '.tasks[] | select(.taskId == $task_id)' "$TASKS_FILE"
}
