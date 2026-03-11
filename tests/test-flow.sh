#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKSPACE_DIR="$HOME/.openclaw/workspace-tech-director"
cd "$ROOT"

bash install.sh >/tmp/tech-director-install.log
cd "$WORKSPACE_DIR"
chmod +x scripts/*.sh

mkdir -p .openclaw-master/logs .openclaw-master/pids .openclaw-master/reports .openclaw-master/worktrees
printf '{"tasks":[]}
' > .openclaw-master/active-tasks.json
rm -f .openclaw-master/logs/* .openclaw-master/pids/* .openclaw-master/reports/* 2>/dev/null || true
rm -rf .openclaw-master/worktrees/* 2>/dev/null || true

REPO="$ROOT"
TASK_ID=$(bash scripts/spawn-worker.sh --repo "$REPO" --base main review smoke-review "git status --short; echo WORKER_DONE" | tail -n 1)
echo "spawned=$TASK_ID"
sleep 2
bash scripts/check-agents.sh >/tmp/tech-director-check.json
status=$(jq -r --arg tid "$TASK_ID" '.tasks[] | select(.taskId == $tid) | .status' .openclaw-master/active-tasks.json)
[[ "$status" == "done" ]] || { echo "Expected done, got: $status" >&2; cat .openclaw-master/active-tasks.json >&2; exit 1; }

TASK_ID_2=$(bash scripts/spawn-worker.sh --repo "$REPO" --base main review deny-commit "git commit --allow-empty -m denied" | tail -n 1)
sleep 2
bash scripts/check-agents.sh >/tmp/tech-director-check-2.json
status2=$(jq -r --arg tid "$TASK_ID_2" '.tasks[] | select(.taskId == $tid) | .status' .openclaw-master/active-tasks.json)
[[ "$status2" == "failed" ]] || { echo "Expected failed for readonly commit block, got: $status2" >&2; cat .openclaw-master/active-tasks.json >&2; exit 1; }

echo "TEST_PASS: flow completed"
