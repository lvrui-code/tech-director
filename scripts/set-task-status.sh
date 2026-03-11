#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

[[ $# -ge 2 ]] || { echo "Usage: set-task-status.sh <task-id> <status> [pr-url] [notes]" >&2; exit 1; }
task_id="$1"; status="$2"; pr_url="${3:-}"; notes="${4:-}"
get_task "$task_id" >/dev/null || { echo "Task not found: $task_id" >&2; exit 1; }
patch=$(jq -nc --arg status "$status" --arg updatedAt "$(now_iso)" --arg lastHeartbeat "$(now_iso)" --arg prUrl "$pr_url" --arg notes "$notes" '{status:$status, updatedAt:$updatedAt, lastHeartbeat:$lastHeartbeat} + (if $prUrl == "" then {} else {prUrl:$prUrl} end) + (if $notes == "" then {} else {notes:$notes} end)')
update_task "$task_id" "$patch"
get_task "$task_id"
