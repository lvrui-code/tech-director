#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

mapfile -t tasks < <(jq -r '.tasks[].taskId' "$TASKS_FILE")
for task_id in "${tasks[@]:-}"; do
  [[ -n "$task_id" ]] || continue
  task_json="$(get_task "$task_id")"
  [[ -n "$task_json" ]] || continue

  session=$(jq -r '.session' <<<"$task_json")
  mode=$(jq -r '.mode // "background"' <<<"$task_json")
  log_file=$(jq -r '.logFile' <<<"$task_json")
  status=$(jq -r '.status' <<<"$task_json")
  pid_file="$PID_DIR/$task_id.pid"
  new_status="$status"
  failure_reason=$(jq -c '.failureReason // null' <<<"$task_json")

  if preserved_status "$status"; then
    update_task "$task_id" "$(jq -nc --arg updatedAt "$(now_iso)" --arg lastHeartbeat "$(now_iso)" '{updatedAt:$updatedAt,lastHeartbeat:$lastHeartbeat}')"
    continue
  fi

  if [[ "$mode" == "tmux" ]]; then
    if tmux has-session -t "$session" 2>/dev/null; then
      new_status="running"; failure_reason='null'
    else
      if grep -q "WORKER_DONE" "$log_file" 2>/dev/null; then new_status="done"; failure_reason='null'; else new_status="failed"; failure_reason='"tmux session exited before completion marker"'; fi
    fi
  else
    if [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
      new_status="running"; failure_reason='null'
    else
      if grep -q "WORKER_DONE" "$log_file" 2>/dev/null; then new_status="done"; failure_reason='null'; else new_status="failed"; failure_reason='"background worker exited before completion marker"'; fi
    fi
  fi

  update_task "$task_id" "$(jq -nc --arg status "$new_status" --arg updatedAt "$(now_iso)" --arg lastHeartbeat "$(now_iso)" --argjson failureReason "$failure_reason" '{status:$status, updatedAt:$updatedAt, lastHeartbeat:$lastHeartbeat, failureReason:$failureReason}')"
done

jq '.' "$TASKS_FILE"
