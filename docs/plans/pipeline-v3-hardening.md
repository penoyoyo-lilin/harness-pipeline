# Harness Pipeline v3 加固方案

> 基于实际项目（llm-api）M2-M7 执行偏差的复盘分析，针对 pipeline 本身的系统性缺陷提出的改进方案。

## 1. 问题诊断

在 llm-api 项目中，M2 Gateway、M3 Billing、M4 Smart Routing 的实际实现与设计文档偏差 30-60%。以下是 5 个已确认的根因：

| # | 根因 | 具体表现 | 导致的缺陷 |
|---|------|---------|-----------|
| R1 | 设计文档无 Phase 分层 | architect 产出无"Phase 1 必做/Phase 2 defer"标记 | NoopEmbedder 被当作可接受方案合入 |
| R2 | 模块分解被跳过 | `docs/plans/*.md` 从未生成，无执行计划 | 无 checklist 核对功能完整性 |
| R3 | 无提交范围控制 | 110 文件一次 Big-bang 提交 | 无法逐模块验证完整性 |
| R4 | 无跨模块集成追踪 | billing-subscription 加了 RPM/TPM，Gateway 未同步 | RPM/TPM 配置定义了但永远不执行 |
| R5 | Review 缺少设计对齐维度 | 审查只看代码质量，不对照设计文档 Phase 表 | 功能遗漏在 review 阶段不被发现 |

---

## 2. 修改范围

本方案修改 harness-pipeline 仓库中的 **3 个文件** + **2 个模板文件**：

| 文件 | 修改类型 | 说明 |
|------|---------|------|
| `skills/architect/SKILL.md` | 修改 | 模块级产出强制包含 Implementation Phases 表 |
| `skills/pipeline/SKILL.md` | 修改 | 新增 3 个门控步骤，修改 Step 8/18/21/23 |
| `skills/review/SKILL.md` | 修改 | 新增设计对齐审查维度 |
| `docs/templates/architecture.md` | 修改 | 模板新增 Implementation Phases 章节 |
| `docs/templates/module-plan.md` | 修改 | 模板新增 Phase 1 功能清单列 |

---

## 3. 具体变更

### 3.1 变更 A：architect 强制输出 Implementation Phases 表

**修改文件**：`skills/architect/SKILL.md`

**位置**：模块级模式的 Step 7（生成模块架构文档）— 文档必须包含的章节列表

**新增章节要求**：

```
##### 7.8 Implementation Phases（强制）

模块架构文档必须包含 Implementation Phases 表，将设计文档中的所有功能点按优先级分层：

| Phase | 优先级 | 功能清单 | 验收标准 | 依赖 |
|-------|--------|---------|---------|------|
| 1 | P0 | 本次编码必须实现的功能 | 每个 P0 功能的验收条件 | 无 |
| 2 | P1 | 可延后但需标注的功能 | — | Phase 1 |
| 3 | P2 | 明确 defer 到未来里程碑的功能 + 目标里程碑 | — | Phase 2 |

规则：
- Phase 1 为空 → /architect 不通过，阻塞流水线
- 每个 Phase 1 功能必须有可测试的验收标准
- Phase 2+ 必须标注 defer 目标（如 "M10 管理后台"）
```

**同步修改**：`docs/templates/architecture.md` — 在模板中新增 `## 10. Implementation Phases` 章节（带示例表格）。

**解决的根因**：R1（设计文档无 Phase 分层）+ R5（Review 无对照基准）

---

### 3.2 变更 B：模块分解强制执行 + Phase 1 功能清单

**修改文件**：`skills/pipeline/SKILL.md`

**位置**：Step 8（模块分解）— 动作列表新增第 7 步

**新增内容**：

```
7. 为每个模块提取 Phase 1 功能清单（从各模块架构文档的 Implementation Phases 表）
8. 将 Phase 1 功能清单写入模块执行计划
```

**位置**：Step 10（模块级 /analyze）之前，新增硬门控检查

**新增 Step 9.5：执行计划完整性检查**：

```
#### Step 9.5：执行计划完整性检查（硬门控）

触发条件：Step 9 人类确认执行计划后，进入模块阶段前。

检查项：
1. `docs/plans/<project>-plan.md` 是否存在？
2. 计划中每个模块是否有 Phase 1 功能清单（非空）？
3. 计划中每个模块是否关联了架构文档路径？

任一不通过 → 阻塞，向人类报告缺失项，等待补充后继续。
模块级模式：检查设计文档的 Implementation Phases 表是否存在且 Phase 1 非空。
```

**同步修改**：`docs/templates/module-plan.md` — 在 Wave 表格中新增 "Phase 1 功能清单" 列。

**解决的根因**：R2（模块分解被跳过）

---

### 3.3 变更 C：编码阶段强制按模块独立提交

**修改文件**：`skills/pipeline/SKILL.md`

**位置**：Step 18（编码）和 Step 23（创建 PR）之间，新增 Step 18.5

**新增 Step 18.5：提交范围检查**：

```
#### Step 18.5：提交范围检查（硬门控）

触发条件：/code-go 和 /code-frontend 完成后，/test 之前。

动作：
1. 执行 `git diff --name-only` 提取变更文件列表
2. 按目录前缀（`internal/domain/<module>/`、`web/apps/...`）分类
3. 统计涉及的模块数

规则：
- 单模块变更 → 直接通过
- 跨模块变更（模块数 > 1）→ 检查是否属于同一 Wave
  - 同一 Wave → 允许，但建议拆分
  - 不同 Wave → 阻塞，要求拆分为独立 commit
- 每个模块至少一个独立 commit，commit message 必须包含模块名

输出：提交范围报告，记录每个模块的文件数和 commit 建议。
```

**解决的根因**：R3（无提交范围控制）

---

### 3.4 变更 D：编码完成后强制 Phase 1 完整性核对

**修改文件**：`skills/pipeline/SKILL.md`

**位置**：Step 21（/review）的审查内容新增维度

**新增审查维度**（插入到 Step 21 的检查清单中）：

```
Phase 1 完整性核对（硬门控）：

1. 读取设计文档 `docs/design-docs/<module>.md` 的 Implementation Phases 表
2. 逐项确认 Phase 1 每个功能是否已实现
3. Phase 1 功能未实现 → 标记为 FAIL（非 tech-debt，必须补实现）
4. Phase 2+ 功能未实现 → 标记为 EXPECTED（合规 defer）

Noop/Stub 审查：
1. 搜索 Noop、Stub、TODO、FIXME、placeholder 关键词
2. 每个 Noop/Stub 必须有关联的 TODO 注释，说明：
   - 替代方案（用什么真实实现替换）
   - 目标 Phase（何时实现）
3. 无注释的 Noop/Stub → 标记为 WARNING
```

**解决的根因**：R5（Review 缺少设计对齐维度）

---

### 3.5 变更 E：架构文档变更时触发跨模块影响分析

**修改文件**：`skills/pipeline/SKILL.md`

**位置**：Step 13（人类审批模块架构）通过后，新增 Step 13.5

**新增 Step 13.5：跨模块影响分析**：

```
#### Step 13.5：跨模块影响分析

触发条件：模块级 /architect 审批通过后，编码开始前。

动作：
1. 提取本模块架构文档中的：
   - 新增/变更的公开 HTTP API 路径
   - 新增/变更的 Service 接口方法
   - 新增/变更的配置项（config.yaml / 新 YAML 文件）
   - 新增/变更的错误码
2. 扫描其他已实现模块的代码，查找是否消费了上述接口/配置
3. 如发现受影响的下游模块：
   a. 在任务 YAML 中记录 `cross_module_impact: [{module, impact, action}]`
   b. 受影响模块的编码阶段必须同步更新
   c. 在模块索引中标记集成依赖

产出：`.harness/reports/cross-module-impact-<module>.md`

跳过条件：模块级模式且无跨模块依赖 → 跳过此步骤。
```

**解决的根因**：R4（无跨模块集成追踪）

---

## 4. 变更影响分析

### 流水线步骤变化总览

```
原有步骤：
  Step 8 模块分解 → Step 9 人类确认 → Step 10 模块 analyze → ... → Step 18 编码 → Step 19 contract-sync → Step 20 test → Step 21 review → Step 22 集成测试 → Step 23 PR

变更后步骤：
  Step 8 模块分解（含 Phase 1 清单）→ Step 9 人类确认 → Step 9.5 执行计划完整性检查 🆕 → Step 10 模块 analyze → ... → Step 13.5 跨模块影响分析 🆕 → Step 18 编码 → Step 18.5 提交范围检查 🆕 → Step 19 contract-sync → Step 20 test → Step 21 review（含 Phase 1 核对 + Noop 审查）📝 → Step 22 集成测试 → Step 23 PR
```

### 新增硬门控汇总

| 门控 | 位置 | 阻断条件 |
|------|------|---------|
| 执行计划完整性 | Step 9.5 | `docs/plans/*.md` 不存在，或 Phase 1 清单为空 |
| 提交范围 | Step 18.5 | 跨 Wave 提交（不同 Wave 的代码混在一个 commit） |
| Phase 1 完整性 | Step 21 | 设计文档 Phase 1 功能有未实现的 |

### 对已有项目的影响

- **不追溯**：已有项目（如 llm-api）的已完成任务不受影响
- **新模块生效**：下次执行 `/pipeline` 时自动应用新规则
- **向后兼容**：所有新规则都是新增门控，不改变已有步骤的行为

---

## 5. 执行计划

本方案自身的修改分为 5 步，按依赖顺序执行：

| 步骤 | 内容 | 依赖 |
|------|------|------|
| 1 | 修改 `docs/templates/architecture.md` — 新增 Phase 模板章节 | 无 |
| 2 | 修改 `docs/templates/module-plan.md` — 新增 Phase 1 清单列 | 无 |
| 3 | 修改 `skills/architect/SKILL.md` — 强制输出 Phase 表 | 步骤 1 |
| 4 | 修改 `skills/review/SKILL.md` — 新增 Phase 1 核对 + Noop 审查 | 步骤 3 |
| 5 | 修改 `skills/pipeline/SKILL.md` — 新增 Step 9.5/13.5/18.5 + 修改 Step 8/21 | 步骤 2,3,4 |

步骤 1 和 2 可并行。步骤 3 和 4 可并行。步骤 5 在 3 和 4 完成后执行。
