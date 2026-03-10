#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

report_file="$REPORT_DIR/status-$(date +%Y%m%d-%H%M%S).md"

queued=$(jq '[.tasks[] | select(.status == "queued")] | length' "$TASKS_FILE")
running=$(jq '[.tasks[] | select(.status == "running")] | length' "$TASKS_FILE")
done_count=$(jq '[.tasks[] | select(.status == "done")] | length' "$TASKS_FILE")
failed=$(jq '[.tasks[] | select(.status == "failed")] | length' "$TASKS_FILE")
blocked=$(jq '[.tasks[] | select(.status == "blocked")] | length' "$TASKS_FILE")

{
  echo "# 技术总监阶段简报"
  echo
  echo "- 生成时间：$(now_iso)"
  echo "- queued：$queued"
  echo "- running：$running"
  echo "- done：$done_count"
  echo "- failed：$failed"
  echo "- blocked：$blocked"
  echo
  echo "## 任务列表"
  jq -r '.tasks[] | "- [\(.status)] \(.taskId) | type=\(.taskType) | title=\(.title)"' "$TASKS_FILE"
} > "$report_file"

cat "$report_file"
