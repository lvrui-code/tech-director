#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

usage() {
  cat <<'EOF'
Usage:
  spawn-worker.sh [--repo <repo-path>] [--base <base-branch>] <task-type> <task-name> <command...>

Examples:
  spawn-worker.sh review audit-pr "git diff --stat; echo WORKER_DONE"
  spawn-worker.sh --repo /path/to/repo --base main code fix-login "pytest -q; echo WORKER_DONE"
EOF
}

repo=""
base_branch="main"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) repo="$2"; shift 2 ;;
    --base) base_branch="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    *) break ;;
  esac
done

[[ $# -ge 3 ]] || { usage; exit 1; }

task_type="$1"; shift
task_name_raw="$1"; shift
command_str="$*"

case "$task_type" in code|doc|review|qa|research) ;; *) echo "Unsupported task type: $task_type" >&2; exit 1 ;; esac
forbidden_git_pattern "$command_str" && { echo "Blocked dangerous git operation in command" >&2; exit 1; }

safe_name="$(sanitize_name "$task_name_raw")"
task_id="task-${task_type}-${safe_name}-$(date +%s)"
session_name="task-${task_type}-${safe_name}"
worktree="$WORKTREE_DIR/$task_id"
log_file="$LOG_DIR/$task_id.log"
pid_file="$PID_DIR/$task_id.pid"
started_at="$(now_iso)"
branch=""
created_git_worktree="false"
repo_python=""
runtime="generic"

if [[ -n "$repo" ]]; then
  has_git_repo "$repo" || { echo "Not a git repo: $repo" >&2; exit 1; }
  branch="${task_type}/${safe_name}-${task_id##*-}"
  git -C "$repo" fetch --all --prune >/dev/null 2>&1 || true
  git -C "$repo" worktree add -b "$branch" "$worktree" "$base_branch" >/dev/null
  created_git_worktree="true"
  if [[ -f "$repo/pyproject.toml" ]]; then
    runtime="python-poetry-shared"
    repo_python="$(repo_venv_python "$repo" || true)"
  fi
else
  mkdir -p "$worktree"
fi

[[ -d "$worktree" ]] || { echo "Failed to prepare worktree: $worktree" >&2; exit 1; }

task_json=$(jq -nc \
  --arg taskId "$task_id" --arg taskType "$task_type" --arg title "$task_name_raw" \
  --arg session "$session_name" --arg repo "$repo" --arg baseBranch "$base_branch" \
  --arg branch "$branch" --arg worktree "$worktree" --arg model "manual" \
  --arg status "running" --arg promptSummary "$command_str" --arg startedAt "$started_at" \
  --arg updatedAt "$started_at" --arg lastHeartbeat "$started_at" --arg logFile "$log_file" \
  --arg mode "background" --arg createdGitWorktree "$created_git_worktree" \
  --arg repoPython "$repo_python" --arg runtime "$runtime" \
  '{taskId:$taskId, taskType:$taskType, title:$title, session:$session, repo:$repo, baseBranch:$baseBranch, branch:$branch, worktree:$worktree, model:$model, status:$status, promptSummary:$promptSummary, deliverables:[], acceptanceCriteria:[], dependsOn:[], parentTaskId:null, prUrl:null, notes:null, failureReason:null, retryCount:0, startedAt:$startedAt, updatedAt:$updatedAt, lastHeartbeat:$lastHeartbeat, logFile:$logFile, mode:$mode, createdGitWorktree:($createdGitWorktree == "true"), repoPython:$repoPython, runtime:$runtime}'
)
append_task "$task_json"

cat <<EOF > "$worktree/run.sh"
#!/usr/bin/env bash
set -euo pipefail
export WORKTREE="$worktree"
export REPO_ROOT="$repo"
export TASK_BRANCH="$branch"
exec "$PROJECT_ROOT/scripts/worker-entry.sh" "$task_type" "$command_str"
EOF
chmod +x "$worktree/run.sh"

if has_tmux; then
  tmux new-session -d -s "$session_name" -c "$worktree" "./run.sh 2>&1 | tee -a '$log_file'"
  update_task "$task_id" "$(jq -nc --arg mode tmux '{mode:$mode}')"
else
  ( cd "$worktree" && ./run.sh >"$log_file" 2>&1 ) &
  echo $! > "$pid_file"
fi

printf '%s\n' "$task_id"
