#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE_DIR="$HOME/.openclaw/workspace-tech-director"
STATE_DIR="$WORKSPACE_DIR/.openclaw-master"
TASKS_FILE="$STATE_DIR/active-tasks.json"
LOG_DIR="$STATE_DIR/logs"
REPORT_DIR="$STATE_DIR/reports"
WORKTREE_DIR="$STATE_DIR/worktrees"
PID_DIR="$STATE_DIR/pids"

mkdir -p "$STATE_DIR" "$LOG_DIR" "$REPORT_DIR" "$WORKTREE_DIR" "$PID_DIR"
[[ -f "$TASKS_FILE" ]] || printf '{"tasks":[]}
' > "$TASKS_FILE"

now_iso() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
has_tmux() { command -v tmux >/dev/null 2>&1; }

sanitize_name() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g'
}

update_task() {
  local task_id="$1" patch="$2" tmp
  tmp=$(mktemp)
  jq --arg task_id "$task_id" --argjson patch "$patch" '.tasks = (.tasks | map(if .taskId == $task_id then . + $patch else . end))' "$TASKS_FILE" > "$tmp"
  mv "$tmp" "$TASKS_FILE"
}
append_task() {
  local task_json="$1" tmp
  tmp=$(mktemp)
  jq --argjson task "$task_json" '.tasks += [$task]' "$TASKS_FILE" > "$tmp"
  mv "$tmp" "$TASKS_FILE"
}
remove_task() {
  local task_id="$1" tmp
  tmp=$(mktemp)
  jq --arg task_id "$task_id" '.tasks |= map(select(.taskId != $task_id))' "$TASKS_FILE" > "$tmp"
  mv "$tmp" "$TASKS_FILE"
}
get_task() {
  local task_id="$1"
  jq --arg task_id "$task_id" -c '.tasks[] | select(.taskId == $task_id)' "$TASKS_FILE"
}

preserved_status() {
  case "$1" in reviewing|changes_requested|merged|closed|cancelled|blocked) return 0 ;; *) return 1 ;; esac
}

has_git_repo() {
  local repo="$1"
  git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

repo_venv_python() {
  local repo="$1"
  if [[ -x "$repo/.venv/bin/python" ]]; then
    printf '%s\n' "$repo/.venv/bin/python"
    return 0
  fi
  if command -v poetry >/dev/null 2>&1; then
    local p
    p=$(cd "$repo" && poetry env info -p 2>/dev/null || true)
    if [[ -n "$p" && -x "$p/bin/python" ]]; then
      printf '%s\n' "$p/bin/python"
      return 0
    fi
  fi
  return 1
}

command_mentions_dependency_files() {
  local s="$1"
  [[ "$s" == *pyproject.toml* || "$s" == *poetry.lock* ]]
}

forbidden_git_pattern() {
  local s="$1"
  [[ "$s" == *"git merge"* || "$s" == *"git push --force"* || "$s" == *"git push -f"* || "$s" == *"git checkout main"* || "$s" == *"git checkout master"* || "$s" == *"git switch main"* || "$s" == *"git switch master"* || "$s" == *"git push origin main"* || "$s" == *"git push origin master"* ]]
}
