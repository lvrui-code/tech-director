#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

report_file="$REPORT_DIR/status-$(date +%Y%m%d-%H%M%S).md"
for status_name in queued running reviewing changes_requested done merged closed failed blocked cancelled; do
  eval "$status_name=\$(jq '[.tasks[] | select(.status == \"'$status_name'\")] | length' \"$TASKS_FILE\")"
done
{
  echo "# 技术总监阶段简报"
  echo
  echo "- 生成时间：$(now_iso)"
  for status_name in queued running reviewing changes_requested done merged closed failed blocked cancelled; do
    eval "val=\$$status_name"; echo "- ${status_name}：$val"
  done
  echo
  echo "## 任务列表"
  jq -r '.tasks[] | "- [\(.status)] \(.taskId) | type=\(.taskType) | title=\(.title) | branch=\(.branch // "") | runtime=\(.runtime // "") | pr=\(.prUrl // "")"' "$TASKS_FILE"
} > "$report_file"
cat "$report_file"
