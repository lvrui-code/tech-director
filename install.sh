#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE_DIR="$HOME/.openclaw/workspace-tech-director"
IDENTITY_DIR="$ROOT/identity"
STATE_DIR="$WORKSPACE_DIR/.openclaw-master"

echo "正在安装技术总监智能体 (tech-director)..."
mkdir -p "$WORKSPACE_DIR" "$STATE_DIR/reports" "$STATE_DIR/logs" "$STATE_DIR/pids" "$STATE_DIR/worktrees"

for f in IDENTITY.md SOUL.md USER.md AGENTS.md TOOLS.md BOOTSTRAP.md REPORTING.md MEMORY.md; do
  if [[ -f "$IDENTITY_DIR/$f" ]]; then
    cp "$IDENTITY_DIR/$f" "$WORKSPACE_DIR/$f"
  fi
done

echo "✅ 已复制身份文档到 $WORKSPACE_DIR"

[[ -f "$STATE_DIR/active-tasks.json" ]] || printf '{"tasks":[]}
' > "$STATE_DIR/active-tasks.json"

echo "✅ 已初始化任务状态目录与注册表"

if [[ -L "$WORKSPACE_DIR/scripts" ]]; then
  rm "$WORKSPACE_DIR/scripts"
elif [[ -d "$WORKSPACE_DIR/scripts" ]]; then
  rm -rf "$WORKSPACE_DIR/scripts"
fi
ln -s "$ROOT/scripts" "$WORKSPACE_DIR/scripts"

echo "✅ 已建立 scripts 目录软链接"

echo ""
echo "安装完成。建议确认以下事项："
echo "1. OpenClaw agent workspace 指向：$WORKSPACE_DIR"
echo "2. agent 至少允许 read / write / exec 工具；若需要会话编排再额外开放 sessions_*"
echo "3. sandbox.mode 允许真实落地（通常为 off）"
echo "4. 若使用 tmux Worker，请确保系统已安装 tmux"
echo "5. 若主要项目为 Python + Poetry，请在目标主仓库准备可复用的 .venv"
echo ""
echo "建议下一步："
echo "- 在项目目录运行冒烟测试：cd $ROOT && bash tests/test-flow.sh"
echo "- 在项目目录阅读运行说明：cd $ROOT && sed -n \"1,120p\" docs/TECH_DIRECTOR_RUNTIME_AND_SECURITY.md"
