# 技术总监运行架构与权限设计说明

本文档描述 `tech-director` 项目的当前落地方案，重点说明：
- 总体架构
- 身份文档体系
- Worker 生命周期
- 最小权限模型
- Python + Poetry 环境策略
- PR 交付与审查流程
- 安装与迁移方式

---

## 1. 总体目标

本项目的目标不是做一个只会回答问题的 agent，而是做一个可持续运行的“技术总监型 AI”，负责：
- 理解老板目标
- 输出方案和验收标准
- 调度 Worker 落地执行
- 跟踪结果与风险
- 通过 PR 交付改动
- 让老板只审 PR，不需要自己翻仓库找改动

---

## 2. 总体架构

```text
Boss
  ↓
技术总监（编排层）
  - 需求澄清
  - 方案设计
  - 任务拆解
  - 风险判断
  - PR 汇报
  ↓
Worker（执行层）
  - code
  - doc
  - review
  - qa
  - research
```

当前最小可运行实现基于：
- `git branch`
- `git worktree`
- `tmux`（可选，优先）
- shell 脚本
- `.openclaw-master/active-tasks.json` 任务注册表

---

## 3. 身份文档体系

项目中的身份文档位于 `identity/`：

- `IDENTITY.md`：我是谁
- `SOUL.md`：我怎么做事
- `USER.md`：老板怎么协作
- `AGENTS.md`：运行规则、交付流程、权限模型
- `TOOLS.md`：工具与脚本说明
- `BOOTSTRAP.md`：新会话启动补充规范
- `REPORTING.md`：汇报模板与口径
- `MEMORY.md`：长期工作记忆

安装脚本会把这些文档复制到 OpenClaw 实际工作区。

---

## 4. Worker 生命周期

### 4.1 创建
通过：

```bash
bash scripts/spawn-worker.sh --repo /path/to/repo --base main code fix-login "pytest -q; echo WORKER_DONE"
```

执行动作：
1. 创建任务记录
2. 基于目标仓库创建独立分支
3. 基于目标仓库创建独立 worktree
4. 生成 `run.sh`
5. 通过 `tmux` 或后台进程启动任务
6. 在任务注册表中记录 repo / branch / worktree / runtime / log 等信息

### 4.2 运行
运行中的任务可通过以下脚本查看：
- `scripts/check-agents.sh`
- `scripts/report-status.sh`

### 4.3 状态管理
支持状态：
- `queued`
- `running`
- `reviewing`
- `changes_requested`
- `done`
- `merged`
- `closed`
- `failed`
- `blocked`
- `cancelled`

### 4.4 收尾
PR 合并或关闭后，或任务已明确结束（如 `done / failed / cancelled`）时，可通过：

```bash
bash scripts/cleanup-worker.sh <task-id>
```

清理：
- tmux 会话
- worktree
- 本地任务分支
- 任务注册表记录

---

## 5. 为什么要用 branch + worktree + PR

### branch
branch 负责版本线。

### worktree
worktree 负责独立工作目录，避免不同任务互相污染。

### PR
PR 是老板的默认审核面。

这三者配合后的收益：
- 每个任务有独立现场
- 不改主工作目录
- 不直接改 `main`
- 老板只看 PR，不用手动翻改动

---

## 6. PR 权限边界

### 老板负责
- 审 PR
- 提意见
- 决定是否合并
- 执行最终 merge

### 技术总监负责
- 创建分支
- 创建 worktree
- 修改
- 自检
- 提交
- push 分支
- 创建 PR
- 跟进 review
- 合并后清理

### 红线
技术总监不得擅自合并 PR。

---

## 7. Worker 最小权限模型（当前落地版）

本项目当前实现的是“基础版最小权限模型（流程约束 + 脚本拦截）”，目标不是一步到位的系统级沙箱，而是用最简单方式解决绝大多数现实风险。

### 7.1 当前主要控制的风险
- 避免改到主工作区
- 避免改错分支
- 避免 review worker 拿到写入能力
- 避免直接 merge PR
- 避免 push 主分支
- 避免 force push
- 避免 Python 大项目每个 worktree 都重装依赖

### 7.2 基础硬规则
1. 一任务一分支
2. 一任务一 worktree
3. Git 写操作仅允许当前任务分支
4. 禁止 merge / force push / push main/master
5. review / qa / research 默认不允许 commit/push
6. Worker 默认最小环境变量启动
7. 业务逻辑、功能边界、范围取舍不由 Worker 自行决定

### 7.3 权限矩阵

#### review
- 允许：读文件、看 diff、看日志、写评审报告、跑只读检查
- 禁止：改代码、commit、push、merge

#### doc
- 允许：改文档、提交当前任务分支
- 禁止：merge

#### code
- 允许：改代码、跑测试、提交当前任务分支
- 禁止：merge、push 主分支、force push

#### qa
- 允许：跑测试、读日志、写报告
- 禁止：commit、push、merge

#### research
- 允许：调研、读取仓库、写报告
- 禁止：commit、push、merge

### 7.4 当前脚本如何实现这些限制

> 注意：当前实现主要依赖命令关键字拦截、分支/worktree 隔离和流程约束，不应表述为“不可绕过的强权限边界”。

#### 1）`spawn-worker.sh`
- 校验任务类型
- 拦截危险 git 命令关键字：
  - `git merge`
  - `git push --force`
  - `git push origin main/master`
  - `git checkout/switch main/master`
- 创建独立分支与 worktree

#### 2）`worker-entry.sh`
- 根据 Worker 类型二次校验命令
- 对 `review / qa / research` 拦截 `git commit` 与 `git push`
- 重置为最小 `PATH`
- 注入最小运行环境
- 在 worktree 中执行命令

#### 3）流程约束
- 只有老板能 merge
- cleanup 默认用于 PR merged / closed 后收尾；若任务已明确结束（如 done / failed / cancelled），也可按实际需要手动清理

> 说明：这不是强隔离或内核级安全边界，当前主要用于降低误操作和流程越权风险。

---

## 8. Python + Poetry 环境策略

### 8.1 设计目标
对于较大的 Python 项目，不让每个 worktree 都重新 `poetry install`，避免严重拖慢开发速度。

### 8.2 当前策略
- **代码隔离**：每任务独立 worktree
- **环境复用**：默认复用主仓库 `.venv`

### 8.3 优先级
Worker 启动时，按下面顺序寻找 Python 运行环境：
1. 主仓库 `.venv/bin/python`
2. Poetry 已存在环境（`poetry env info -p`）
3. 若仍缺失，再人工决定是否安装依赖

### 8.4 仅在这些情况刷新依赖
- 主环境不存在
- `pyproject.toml` 变更
- `poetry.lock` 变更
- 依赖问题导致验证失败
- 老板明确要求重建环境

### 8.5 这样做的收益
- 保持 worktree 的代码隔离
- 避免大项目重复安装依赖
- 让 Worker 启动速度可接受

---

## 9. PR 自动化的真正意义

PR 自动化不是自动合并，不是替老板做决策，而是：
1. 把交付面标准化
2. 把过程留痕
3. 把技术性问题前置审查
4. 把老板的注意力保留给业务取舍与合并决策

---

## 10. Review 审查策略

### 轻量任务
- 1 个 review agent 即可

### 中高风险任务
- 2 个及以上不同模型/不同视角 review agent

### review 意见处理规则

#### 可直接处理
- 明确 bug
- 明确逻辑错误
- 安全风险
- 与需求冲突
- 验收无法通过

#### 需要老板拍板
- 业务逻辑变化
- 功能定义变化
- 范围扩大或收缩
- 体验取舍
- 排期与质量权衡

处理方式：先总结、再给选项、等老板拍板后再改。

---

## 11. 运行目录与状态目录

默认工作区：
- `~/.openclaw/workspace-tech-director`

状态目录：
- `.openclaw-master/active-tasks.json`
- `.openclaw-master/logs/`
- `.openclaw-master/reports/`
- `.openclaw-master/pids/`
- `.openclaw-master/worktrees/`

---

## 12. 安装设计

安装脚本 `install.sh` 负责：
1. 创建 workspace
2. 复制身份文档
3. 初始化 `.openclaw-master/`
4. 建立 `scripts/` 软链接
5. 初始化任务注册表
6. 输出后续操作说明

说明：当前安装脚本不会把仓库内 `docs/` 和 `tests/` 复制到 workspace；相关阅读和测试应在项目仓库目录中执行。

---

## 13. 当前方案的边界

当前是“简单基础版”，不是最终强隔离版。

### 当前没有做到的事
- 没有容器级隔离
- 没有独立 Linux 用户隔离
- 没有完整命令 allowlist 解释器
- 没有完全阻断所有 shell 绕过方式

### 为什么现在不先做这些
因为当前阶段最重要的是：
- 先落地
- 先可用
- 先把绝大多数风险控住
- 先让交付链路闭环

后续再逐步升级到更硬的隔离方式。

---

## 14. 推荐后续升级路线

### 第一步（当前已做）
- branch + worktree + PR
- 最小环境变量
- Worker 类型分权
- Poetry 环境复用

### 第二步（下一阶段）
- 更细的命令白名单
- review worker 更严格只读限制
- PR 自动创建与回写注册表

### 第三步（后续）
- 独立系统用户
- 容器化 Worker
- 网络访问隔离
- 更强凭据隔离

---

## 15. 一句话总结

当前 `tech-director` 项目采用的是：

> **编排层技术总监 + 受限执行 Worker + branch/worktree/PR 交付链路 + Python 环境复用 + 基础版权限控制**

它的目标不是一开始做到最重的安全体系，而是用最简单可落地的方式，先把绝大多数风险控住，并让整体流程真正跑起来。
