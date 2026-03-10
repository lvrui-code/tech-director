#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

usage() {
  cat <<'EOF'
Usage:
  spawn-worker.sh <task-type> <task-name> <command...>

Example:
  spawn-worker.sh doc architecture-refresh bash -lc 'echo done'
EOF
}

[[ $# -ge 3 ]] || { usage; exit 1; }

task_type="$1"; shift
task_name_raw="$1"; shift
command_str="$*"

safe_name="$(sanitize_name "$task_name_raw")"
task_id="task-${task_type}-${safe_name}-$(date +%s)"
session_name="task-${task_type}-${safe_name}"
worktree="$WORKTREE_DIR/$task_id"
log_file="$LOG_DIR/$task_id.log"
pid_file="$PID_DIR/$task_id.pid"
started_at="$(now_iso)"

mkdir -p "$worktree"

task_json=$(jq -nc \
  --arg taskId "$task_id" \
  --arg taskType "$task_type" \
  --arg title "$task_name_raw" \
  --arg session "$session_name" \
  --arg branch "" \
  --arg worktree "$worktree" \
  --arg model "manual" \
  --arg status "running" \
  --arg promptSummary "$command_str" \
  --arg startedAt "$started_at" \
  --arg updatedAt "$started_at" \
  --arg lastHeartbeat "$started_at" \
  --arg logFile "$log_file" \
  --arg mode "background" \
  '{taskId:$taskId, taskType:$taskType, title:$title, session:$session, branch:$branch, worktree:$worktree, model:$model, status:$status, promptSummary:$promptSummary, deliverables:[], acceptanceCriteria:[], dependsOn:[], parentTaskId:null, prUrl:null, failureReason:null, retryCount:0, startedAt:$startedAt, updatedAt:$updatedAt, lastHeartbeat:$lastHeartbeat, logFile:$logFile, mode:$mode}'
)
append_task "$task_json"

if has_tmux; then
  tmux new-session -d -s "$session_name" -c "$worktree" "bash -lc '$command_str' | tee -a '$log_file'"
  update_task "$task_id" "$(jq -nc --arg mode tmux '{mode:$mode}')"
else
  bash -lc "cd '$worktree' && { $command_str; }" >"$log_file" 2>&1 &
  echo $! > "$pid_file"
fi

printf '%s\n' "$task_id"
