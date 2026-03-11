# tech-director

AI 技术总监项目工程。

## 项目目标

把“技术总监”从一份架构文档逐步落地为一个可运行、可迁移、可扩展的项目工程，包括：

- 架构文档与运行说明
- 身份文档体系
- Worker 编排脚本
- 任务注册表
- PR 交付与审查流程
- 最小权限模型
- Python + Poetry 环境复用策略
- 一键安装脚本

---

## 目录结构

- `docs/`：架构、运行、安全、安装说明
- `identity/`：技术总监身份文档
- `scripts/`：编排脚本与 Worker 启动入口
- `tests/`：最小流程测试
- `.openclaw-master/`：运行时状态（默认忽略）

---

## 核心设计

### 1. 交付面
默认交付面不是口头汇报，而是：
- 独立分支
- 独立 worktree
- commit
- PR
- review
- 合并后清理

### 2. 权限边界
- 老板负责审 PR 与 merge
- 技术总监负责创建分支、worktree、PR、review 跟进与清理
- Worker 默认最小权限运行

### 3. Python 项目策略
对于大 Python + Poetry 项目：
- worktree 用来隔离代码
- 主仓库 `.venv` 用来复用运行环境
- 默认不为每个 worktree 重装依赖

---

## 快速开始

### 安装到 OpenClaw 工作区

```bash
cd /home/lvrui/tech-director
bash install.sh
```

### 运行最小流程测试

```bash
cd /home/lvrui/tech-director
bash tests/test-flow.sh
```

---

## 关键文档

- 架构主文档：`docs/MULTI_AGENT_DISCORD_ARCHITECTURE_PLAN.md`
- 运行与安全说明：`docs/TECH_DIRECTOR_RUNTIME_AND_SECURITY.md`

---

## 核心脚本

- `scripts/spawn-worker.sh`：创建任务、分支、worktree、启动 Worker
- `scripts/worker-entry.sh`：Worker 最小权限入口
- `scripts/check-agents.sh`：更新任务状态
- `scripts/report-status.sh`：输出阶段简报
- `scripts/cleanup-worker.sh`：合并或关闭后清理任务现场
- `scripts/set-task-status.sh`：手动推进任务状态

---

## 当前实现特点

已具备：
- branch + worktree + PR 生命周期基础模型
- Worker 最小权限基础版
- review / qa / research 默认禁止 commit/push
- 禁止 merge / force push / 直接 push 主分支
- Python + Poetry 主环境复用策略
- 安装脚本可将项目导入其他 OpenClaw 环境

---

## 说明

当前实现强调：
- 先落地
- 先控住大多数风险
- 先让交付链路闭环

不是一开始就上最重的系统级隔离。后续可逐步升级为更强的命令白名单、独立用户或容器化方案。
