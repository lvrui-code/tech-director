#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

chmod +x scripts/*.sh
printf '{"tasks":[]}
' > .openclaw-master/active-tasks.json
rm -f .openclaw-master/logs/* .openclaw-master/pids/* .openclaw-master/reports/* 2>/dev/null || true
rm -rf .openclaw-master/worktrees/* 2>/dev/null || true

TASK_ID=$(bash scripts/spawn-worker.sh doc smoke-test "bash -lc 'echo start; sleep 1; echo WORKER_DONE'" | tail -n 1)

echo "spawned=$TASK_ID"
sleep 2
bash scripts/check-agents.sh >/tmp/tech-director-check.json
status=$(jq -r --arg tid "$TASK_ID" '.tasks[] | select(.taskId == $tid) | .status' .openclaw-master/active-tasks.json)

if [[ "$status" != "done" ]]; then
  echo "Expected done, got: $status" >&2
  cat .openclaw-master/active-tasks.json >&2
  exit 1
fi

bash scripts/report-status.sh >/tmp/tech-director-report.txt
[[ -s /tmp/tech-director-report.txt ]]
grep -q "done：1" /tmp/tech-director-report.txt

echo "TEST_PASS: flow completed"
