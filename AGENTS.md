# Harness Pipeline — Agent Team 总调度

> **项目类型**: Go 后端 + 前端 Web 应用  
> **团队规模**: 1-5 人  
> **代码仓库即记录系统**: 所有产出物均在仓库结构化目录中

---

## 架构约束

> 以下为框架推荐的默认架构。**实际技术选型由项目级 `docs/design-docs/architecture.md` 定义**，各项目可根据需求选择不同的 HTTP 框架、ORM 和前端方案，但须遵守分层依赖方向的约束。

1. **Go 后端**: `internal/domain/<module>/` 按 Domain 分层 — types → config → repository → service → handler → router，**严禁内层引用外层**
2. **前端**: 默认 Server Component / 函数组件，需交互才用 Client Component。框架可选 Next.js（SSR/ISR）或 Vite + React（SPA）
3. **依赖方向**: handler → service → repository → types（严格单向）
4. **API 格式**: 统一 `{ code: 0, message: "", data: {} }` 响应结构，错误码见 `docs/design-docs/architecture.md`
5. **API 契约唯一真相**: 对外 HTTP 接口必须以项目 `docs/design-docs/architecture.md` 中定义的 OpenAPI 文件路径为准（推荐 `docs/api-specs/<module-name>.yaml` 或 `docs/api/openapi.yaml`）；需求/架构文档仅保留摘要和跳转
6. **分支策略**: main（生产）← develop（开发）← feature/*（功能）

   **分支命名规范（多人协作）**：
   - AI Agent 生成的分支：`ai/<task-id>-<module>`，如 `ai/req-user-registration-user`
   - 人类开发者分支：`human/<name>-<feature>`，如 `human/alice-payment-flow`
   - 前缀用于区分 PR 来源，避免与人类开发者的分支冲突

7. **多人协作 PR 规范**：
   - 同一模块被多个并行任务修改时，pipeline 在编码完成后执行冲突预检
   - Wave 内模块如无被依赖关系，可独立合入 develop，不必等待同 Wave 全部完成

---

## Agent Team 协作协议

### 流水线模式

流水线支持两种模式，由 `/pipeline` 根据需求复杂度自动判断：

| 模式 | 触发条件 | 流程 |
|------|---------|------|
| **模块级**（单阶段） | 单模块需求，项目已有全局架构 | `/analyze` → `/architect` → ... → PR |
| **项目级**（两阶段） | 多模块需求，或无全局架构 | `/analyze(PRB)` → `/architect(全局)` → `/design-ui(全局规范)` → 模块分解 → 全部模块设计 → 全局设计对齐 → 按 Wave 编码 |

> 详细判断规则见 `CLAUDE.md`。

### 可用 Skills（按流水线顺序）

| 阶段 | Skill 命令 | 职责 | 模式 | 必选 | 人类审批 |
|------|-----------|------|------|------|---------|
| 需求 | `/analyze` | 拆解需求、定义验收标准 | 项目级 → PRB / 模块级 → 详细需求 | ✅ | ✅ 需求确认 |
| 设计 | `/architect` | 技术方案、数据库模型、API 契约 | 项目级 → 全局架构 / 模块级 → 模块架构+OpenAPI | ✅ | ✅ 架构审批 |
| 规划 | 模块分解 | 模块清单、依赖图、Wave 排序 | 项目级（pipeline 内置） | 复杂项目 | ✅ 计划确认 |
| 对齐 | 设计对齐检查 | 跨模块设计一致性校验 + 自动修复 | 项目级（pipeline 内置） | 全部模块设计完成后 | ✅ 对齐确认 |
| 设计 | `/design-ui` | 项目级→全局设计规范 / 模块级→HTML原型 | 两种 | 有 UI 需求时 | ✅ 设计审批 |
| 编码 | `/code-go` | Go Domain 分层实现 | 模块级 | ✅ | ❌ |
| 编码 | `/code-frontend` | 前端实现（Next.js / Vite+React） | 模块级 | ✅ | ❌ |
| 同步 | `contract-sync` | 契约一致性检查（编码与测试间的门控） | 模块级 | 有 API 变更时 | ❌ |
| 测试 | `/test` | 生成并执行测试 | 模块级 | ✅ **硬门控** | ❌ |
| 审查 | `/review` | 代码审查 + 架构合规 | 模块级 | ⚠️ 软门控 | ❌ |
| 监控 | `/entropy` | 扫描代码偏差 | 独立运行 | ❌ | ❌ |
| 方法 | `modular-vibe-coding` | 模块化编码方法论与模板 | 参考规范 | ❌ | ❌ |
| 编排 | `/pipeline` | 端到端编排（需求→PR，支持多模块） | 两种模式 | ✅ | ✅ 关键节点 |

> **硬门控**：不可跳过，不通过则不可进入下一阶段。
> **软门控**：建议执行，跳过需在任务 YAML 的 `summary` 中记录原因。

### 质量门控

| 门控 | 类型 | 位置 | 说明 |
|------|------|------|------|
| 需求确认 | 人类审批 | `/analyze` → `/architect` | 需求文档必须人类确认 |
| 架构审批 | 人类审批 | `/architect` → 编码 | 技术方案必须人类审批 |
| 设计对齐检查 | 自动检查 + 人类确认 | 全部模块设计完成 → 编码 | 跨模块设计一致性校验，自动修复后人类确认 |
| contract-sync | 自动检查 | 编码 → `/test` | API 契约三层一致性通过 |
| 测试通过 | 自动检查 | `/test` → `/review` 或 PR | 测试失败不可创建 PR |
| 代码审查 | 软门控 | `/test` → PR | 建议执行，跳过需记录原因 |

### review 退回规则

`/review` 发现问题需要回到编码阶段时：

1. **退回粒度**：退回到具体模块/文件级别，而非整个编码阶段
2. **循环限制**：同一模块最多允许 3 次 `review → coding` 循环
3. **超限处理**：超过 3 次后升级为人类决策节点，由人工判断是继续修改还是调整设计
4. **重新测试**：修改后必须重新执行 `/test`，再重新 `/review`

### 并行规则
- `/code-go` 和 `/code-frontend` 可并行执行（各自独立 worktree）
- 各自提交到 `ai/<task-id>-<module>-backend` 和 `ai/<task-id>-<module>-frontend`
- 编码完成后必须先通过 `contract-sync`（代码实现 / OpenAPI / 前端调用类型一致性检查）
- `/test` 在 `contract-sync` 通过后执行
- `/review` 在测试通过后执行

### 并行编码合并策略

`/code-go` 和 `/code-frontend` 并行完成后，按以下流程合并：

1. **各自提交**：后端代码提交到 `ai/<task-id>-<module>-backend`，前端代码提交到 `ai/<task-id>-<module>-frontend`
2. **顺序合并**：先合并 backend 到 `ai/<task-id>-<module>`，再合并 frontend
3. **冲突处理**：合并冲突通常集中在 `docs/api-specs/`（双方可能都修改了 OpenAPI 文件），由 pipeline Agent 协调解决
4. **合并后验证**：合并完成后执行 `go build` / `npm run build` 确保编译通过

### 多人协作冲突预检

编码完成后，pipeline 自动扫描本分支变更文件列表，与 `.harness/tasks/` 中其他 `in_progress` 任务的 `output_path` 做交集：

| 情况 | 动作 |
|------|------|
| 无文件重叠 | 继续 |
| 有重叠且不同 Wave | **阻塞**，两个任务协调合并顺序 |
| 有重叠且同 Wave 且无相互依赖 | 警告，建议先合入者通知后合入者 rebase |
| 有重叠且同 Wave 且有依赖 | 被依赖方先合，依赖方 rebase 后继续 |

### contract-sync 契约同步检查

`contract-sync` 是编码与测试之间的硬门控，确保三层一致性：

| 检查维度 | 说明 | 通过标准 |
|---------|------|---------|
| 后端路由 ↔ OpenAPI | 后端注册的 HTTP 路径与 OpenAPI 文件中的 paths 一致 | 无新增/删除的路由未在 OpenAPI 中体现 |
| 请求/响应结构 ↔ OpenAPI | Handler 的请求解析和响应格式与 OpenAPI schema 一致 | 无字段缺失或类型不匹配 |
| 前端 API 调用 ↔ OpenAPI | 前端的 API Client 调用路径和参数与 OpenAPI 一致 | 无硬编码的路径或缺失的参数 |

- **输入**：项目 `docs/design-docs/architecture.md` 中定义的 OpenAPI 文件 + 后端路由代码 + 前端 API 调用代码
- **执行方式**：调用 `scripts/contract_sync.sh <project-dir>`
- **失败处理**：不一致项必须修复后重新检查，或由人类确认后标记 `doc_sync_status: fail` 并注明原因

### 人类审批节点
当流水线到达以下节点时，**暂停执行，等待人类确认**：

**项目级审批**（两阶段流水线）：
1. **PRB 确认**: `/analyze` 项目级产出 PRB 后 → 等待用户确认
2. **全局架构审批**: `/architect` 项目级产出全局架构后 → 等待用户审批
3. **全局设计规范审批**: `/design-ui` 项目级产出全局设计规范后 → 等待用户审批
4. **执行计划确认**: 模块分解产出执行计划后 → 等待用户确认模块划分和优先级
5. **设计对齐确认**: 全部模块设计完成后，全局设计对齐检查 + 自动修复 → 等待用户确认检查结论

**模块级审批**（两种模式通用）：
6. **需求确认**: `/analyze` 模块级产出需求文档后 → 等待用户确认
7. **架构审批**: `/architect` 模块级产出技术方案后 → 等待用户审批
8. **设计审批**: `/design-ui` 产出原型后 → 等待用户确认

审批方式：在 Claude Code 交互模式中直接回复"确认"/"通过"继续，或提出修改意见。

---

## 任务状态文件规范

Agent 间通过 `.harness/tasks/` 目录下的 YAML 文件通信。以下为任务状态的完整生命周期：

```
                    ┌──────────────┐
                    │   pending    │
                    └──────┬───────┘
                           │ 启动
                           ▼
                    ┌──────────────┐
              ┌────│ in_progress  │────┐
              │    └──────┬───────┘    │
              │           │            │
         停滞 >4h    完成/需审批    执行失败
              │           │            │
              ▼           ▼            ▼
       ┌────────────┐ ┌──────────────────────┐
       │   paused   │ │ waiting_approval     │
       │            │ └──────────┬───────────┘
       │  恢复 →    │            │
       │  in_progress│    ┌───────┴───────┐
       └─────┬──────┘    │               │
             │     审批通过  审批拒绝    │
             │           │               │
             │           ▼               ▼
             │    ┌──────────┐    ┌────────────────┐
             │    │completed │    │ needs_revision │
             │    └──────────┘    └───────┬────────┘
             │                           │
             │                    修改后 → in_progress
             │
             └──────────── 重新启动 → in_progress
```

### 状态枚举

| 状态 | 含义 | 可转换到 |
|------|------|---------|
| `pending` | 已创建，等待执行 | `in_progress` |
| `in_progress` | 正在执行 | `waiting_approval`、`paused`、`completed`、`failed`、`needs_revision` |
| `waiting_approval` | 等待人类审批 | `completed`（通过）、`needs_revision`（拒绝） |
| `paused` | 停滞（超过 4h 无更新或手动暂停） | `in_progress` |
| `needs_revision` | 审批拒绝或 review 发现问题，需修改 | `in_progress` |
| `completed` | 执行完成 | - |
| `failed` | 执行失败 | `in_progress`（重试） |

### 执行纪律（框架级强制）

1. **状态实时更新**：每个 Skill 步骤完成后，**立即**更新任务 YAML 的 `status` 和 `updated_at`，禁止批量补刷
2. **output_path 非空**：任务标记 `completed` 时，`output_path` 必须列出所有实际产出文件；如无文件产出，在 `summary` 中说明
3. **执行日志**：每个任务必须有 `.harness/logs/<task-id>.md`，记录每个步骤的开始/结束时间和调用方式
4. **停滞检测**：`in_progress` 超过 4h 无更新 → 必须标记为 `paused` 并填写 `status_reason`
5. **Skill 调用方式**：流水线中的每个阶段必须通过 Skill 工具调用（`/analyze`、`/architect` 等），禁止用 Agent 工具绕过 Skill 直接生成文档或代码

---

```yaml
# .harness/tasks/<task-id>.yaml
version: "1.0"
task_id: "req-user-registration"
title: "用户注册模块"
status: "completed"        # pending | in_progress | waiting_approval | paused | needs_revision | completed | failed
agent_role: "analyze"       # 当前/最终负责的 Agent 角色
created_at: "2026-03-24T10:00:00Z"
updated_at: "2026-03-24T10:30:00Z"
dependencies: []            # 前置任务的 task_id 列表（仅 task_id，用于依赖检查和拓扑排序）
references: []               # 需要阅读的文档路径（不用于依赖检查，仅作上下文参考）
output_path: "docs/requirements/user-registration.md"
next_skills:                # 下一步应调用的 Skills
  - "architect"
approval_required: true     # 是否需要人类审批
approval_status: "approved" # pending | approved | rejected | n/a
summary: "任务执行摘要"     # 完成后填写执行摘要

# --- 以下字段仅在涉及 API 契约的任务中使用（非必填）---
contract_path: "docs/api-specs/user-registration.yaml"
contract_sha256: "<sha256>"
contract_status: "approved" # draft | approved | drifted
doc_sync_status: "pass"     # pass | fail | pending
reapproval_required: false
blocking_gates:
  - "api_spec_present"
  - "api_spec_approved"
  - "api_doc_sync_passed"
  - "api_contract_tests_passed"

# --- 以下字段为实际执行中扩展的辅助字段（可选）---
# status_label: "已完成"           # 人类可读的状态描述
# stage_label: "全部阶段完成"       # 当前阶段描述
# agent_role_label: "需求分析"      # 人类可读的角色描述
# output_path_label: [...]          # output_path 的中文描述
# dependencies_label: [...]         # dependencies 的中文描述
# next_skills_label: [...]          # next_skills 的中文描述
# status_reason: "停滞原因"         # paused 状态的说明
# phases: [...]                     # 多阶段任务的子阶段追踪
```

> **注意**：以上 schema 在实际项目执行中已有扩展。vibeengine 项目增加了 `_label` 后缀的人类可读字段、`status_reason`（停滞原因）、`phases`（子阶段追踪）等。建议新项目保持核心字段一致，`_label` 辅助字段按需添加。

---

## 文件导航

| 文档 | 路径 | 用途 |
|------|------|------|
| 执行指令 | `CLAUDE.md` | Claude Code 两阶段流水线分支判断规则（Claude 优先读取） |
| 模块索引 | `docs/modules/_index.md` | 所有业务模块的文档、状态和交付链路（自动维护） |
| PRB | `docs/requirements/<project>-prb.md` | 项目级产品需求文档（两阶段流水线） |
| 模块计划 | `docs/plans/<project>-plan.md` | 模块分解与 Wave 执行计划（两阶段流水线） |
| API 契约 | `docs/api-specs/` | 模块级 OpenAPI 契约（唯一真相） |
| 系统架构 | `docs/design-docs/architecture.md` | 全局架构设计 |
| Go 规范 | `docs/references/go-conventions.md` | Go 编码规范 |
| Next.js 规范 | `docs/references/nextjs-conventions.md` | 前端编码规范（Next.js 项目） |
| 前端规范 | `docs/references/frontend-conventions.md` | 前端编码规范（Vite+React 项目） |
| CI/CD | `docs/references/ci-cd.md` | 持续集成说明 |
| ADR | `docs/design-docs/adr/` | 架构决策记录 |
| 需求模板 | `docs/templates/requirement.md` | 模块级需求文档模板 |
| PRB 模板 | `docs/templates/prb.md` | 项目级产品需求文档模板 |
| 架构模板 | `docs/templates/architecture.md` | 模块级架构文档模板 |
| 模块计划模板 | `docs/templates/module-plan.md` | 模块执行计划模板 |
| UI 模板 | `docs/templates/ui-spec.md` | UI 原型参考模板 |
| 全局设计规范 | `docs/design-specs/global-design-spec.md` | 全局 UI 设计规范（项目级一次性确定） |
| 熵值报告 | `docs/entropy-report.md` | 代码健康扫描报告（自动生成） |
| Skill 定义 | `skills/` | 流水线配套 Skill 定义（init.sh 安装到目标项目 `.claude/skills/`） |

---

## 代码风格（关键品味规则）

1. **Go**: 错误处理不吞掉，Service 层返回业务 error，Handler 层统一映射 HTTP 状态码
2. **Go**: 接口定义在使用方（consumer），不在实现方
3. **Go**: 表驱动测试（table-driven tests）
4. **Go**: Handler 使用标准 `http.HandlerFunc` 签名（框架无关），具体路由注册按项目选型（Chi/Gin/Echo）
5. **前端**: 组件默认 Server Component / 函数组件，需要交互才加 `'use client'`
6. **前端**: 服务端状态用 TanStack Query，UI 状态用 useState/Zustand
7. **通用**: 变量命名说人话，禁止 `tmp`/`obj`/`data`/`info` 等模糊命名
8. **通用**: 提交信息格式 `<type>(<scope>): <description>`，如 `feat(user): add email registration`

---

## 安全边界

- 编码 Agent 的爆炸半径：**限定在单个 Domain/模块内**，不得跨模块修改
- 所有写入操作前必须先读取现有代码，理解上下文
- 删除代码需要人类确认
- 数据库 migration 只能加列，不能删列/改列类型
