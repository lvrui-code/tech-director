# TOOLS.md - 技术总监本机说明

## OpenClaw 真实运行环境

- 当前默认工作区 (Workspace)：`/home/lvrui/.openclaw/workspace-tech-director`
- 当前脚本目录：`/home/lvrui/.openclaw/workspace-tech-director/scripts`
- 当前任务状态目录：`/home/lvrui/.openclaw/workspace-tech-director/.openclaw-master`
- OpenClaw 官方文档参考：`/home/lvrui/.npm-global/lib/node_modules/openclaw/docs`

## Worker 最小权限实现原则

先做简单基础版，优先解决绝大多数现实风险，不一开始上重型隔离。

### 基础版控制目标
1. 避免改到主工作区
2. 避免改错分支
3. 避免 review worker 获得写代码能力
4. 避免 worker 擅自 merge PR
5. 避免把全量环境变量和凭据暴露给 worker
6. 避免大 Python 项目每次 worktree 都重装依赖

### 基础版最小实现
- 每任务独立 worktree
- 每任务独立分支
- Git 写操作仅允许当前任务分支
- 禁止 merge / push 主分支 / force push
- 按 worker 类型分权
- 默认最小环境变量启动
- Python + Poetry 项目默认复用主仓库 `.venv`
- 仅在依赖变化或环境缺失时才刷新依赖

### Worker 类型最小权限矩阵
#### review
- 默认只读
- 允许：读文件、git diff、git log、跑只读检查、写评审报告
- 禁止：改代码、git commit、git push、merge

#### doc
- 允许：改文档、git add/commit/push 当前任务分支
- 禁止：改核心代码、merge

#### code
- 允许：改代码、跑测试、git add/commit/push 当前任务分支
- 禁止：merge、push main/master、force push

#### qa
- 允许：跑测试、读日志、写测试报告
- 默认禁止：改代码、merge

#### research
- 默认只读
- 允许：调研、读取仓库、输出报告
- 默认禁止：改代码、merge

## Python + Poetry 环境策略

对于较大的 Python 项目，默认采用：
- **代码用 worktree 隔离**
- **运行环境复用主仓库 `.venv`**

### 默认优先级
1. 优先使用主仓库 `.venv/bin/python`
2. 若主仓库无 `.venv`，再尝试 Poetry 已存在环境
3. 若环境缺失或依赖变更，再考虑 `poetry install`

## 脚本控制台
- `scripts/spawn-worker.sh`
- `scripts/worker-entry.sh`
- `scripts/check-agents.sh`
- `scripts/report-status.sh`
- `scripts/cleanup-worker.sh`
- `scripts/set-task-status.sh`

## 默认规则
- 正式项目修改默认：一任务一分支、一任务一 worktree
- 老板拥有 PR merge 权限；技术总监不得擅自合并
- PR 存活期间保留对应 worktree，便于根据 review 继续修改
- PR merged / closed 后再清理现场
- 涉及业务与功能层的 review 意见，先汇报老板再修改
