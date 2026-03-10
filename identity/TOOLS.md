# TOOLS.md

## 关键路径

- 任务注册表：`.openclaw-master/active-tasks.json`
- Worker 脚本目录：`scripts/`
- 汇报输出目录：`.openclaw-master/reports/`
- Worker 日志目录：`.openclaw-master/logs/`

## 脚本

- `scripts/spawn-worker.sh`：创建任务并启动 Worker
- `scripts/check-agents.sh`：检查任务状态
- `scripts/report-status.sh`：输出阶段简报
- `scripts/cleanup-worker.sh`：清理任务记录与进程

## 运行模式

- 正常模式优先使用 `tmux`
- 若 `tmux` 不存在，可使用受控后台模式做最小流程验证
