# Harness Pipeline — Claude Code 执行指令

## 两阶段流水线分支判断

在接到用户需求后，**必须先判断走项目级还是模块级**：

### 判断规则

**走项目级（两阶段）** — 满足以下任一条件：
1. 需求涉及 **2 个以上** 业务域（如用户管理 + 订单 + 支付）
2. 需求描述中包含多个独立功能模块
3. 用户显式要求"先做整体设计"
4. 项目尚未有全局架构文档（`docs/design-docs/architecture.md` 不存在或为模板占位）

**走模块级（单阶段）** — 满足以下全部条件：
1. 需求明确指向 **单个模块/功能**
2. 项目已有全局架构文档且已审批
3. 不需要新增跨模块依赖

### 项目级流水线

```
用户需求
  → /analyze(PRB)           产出 docs/requirements/<project>-prb.md
  → ⏸ 人类确认 PRB
  → /architect(全局)         产出 docs/design-docs/architecture.md
  → ⏸ 人类审批全局架构
  → /design-ui(全局规范)     产出 docs/design-specs/global-design-spec.md
  → ⏸ 人类审批全局设计规范
  → 模块分解                  产出 docs/plans/<project>-plan.md
  → ⏸ 人类确认执行计划
  ─────── 设计阶段：按 Wave 串行，Provider 先行 ───────
  → Wave 1 模块：analyze → ⏸ → architect → ⏸ → design-ui → ⏸ → 契约冻结
  → Wave 2 模块：analyze(读 Wave 1 已冻结 OpenAPI) → ⏸ → architect → ⏸ → design-ui → ⏸ → 契约冻结
  → ... 后续 Wave 同理
  → 全局设计对齐校验    产出 .harness/reports/design-alignment-report.md
  → ⏸ 人类确认校验结论
  ─────── 编码阶段：按 Wave 分批执行 ───────
  → 按 Wave 顺序逐模块执行 code → 提交范围检查 → 冲突预检 → contract-sync → test → review → 集成测试 → develop同步 → PR
```

### 模块级流水线

```
用户需求
  → /analyze(模块级)      产出 docs/requirements/<module>.md
  → ⏸ 人类确认需求
  → /architect(模块级)    产出 docs/design-docs/<module>.md + docs/api-specs/<module>.yaml
  → ⏸ 人类审批架构
  → /design-ui → code → test → review → 集成测试 → PR
```

## /analyze 模式切换

- **项目级**：`/analyze` 接收用户原始需求，产出高层 PRB（产品需求文档）
  - 内容：产品愿景、用户角色、用户故事、功能范围总览表、非功能需求
  - 不涉及：数据模型细节、API 设计、字段级规格
  - 产出路径：`docs/requirements/<project>-prb.md`

- **模块级**：pipeline 调用时传入模块上下文（PRB + 全局架构 + 执行计划中的模块描述）
  - 内容：详细功能点、数据模型草案、API 契约草案、错误码、验收标准 checklist
  - 产出路径：`docs/requirements/<module>.md`

## /architect 模式切换

- **项目级**：基于 PRB 产出全局技术方案
  - 内容：技术选型、系统架构图、模块边界定义、共享设计决策、ER 概览
  - 不涉及：模块内部分层、字段级数据模型、Go 代码骨架
  - 产出路径：`docs/design-docs/architecture.md`

- **模块级**：基于模块需求 + 全局架构产出模块技术方案
  - 内容：分层目录结构、字段级数据模型、完整 OpenAPI、**对外接口暴露设计和接口契约**、Go 代码骨架、测试策略
  - 产出路径：`docs/design-docs/<module>.md` + `docs/api-specs/<module>.yaml`

## /design-ui 模式切换

- **项目级**：基于 PRB + 全局架构产出全局 UI 设计规范
  - 内容：配色方案、排版规范、间距系统、组件库规范、响应式断点、交互模式
  - 产出路径：`docs/design-specs/global-design-spec.md`
  - **一次性确定，各模块不再产出独立的设计规范**

- **模块级**：基于模块需求 + 全局设计规范产出 HTML 原型
  - 内容：可交互 HTML 原型（遵循全局设计规范）
  - 产出路径：`docs/ui-prototypes/<page-name>.html`
  - **不产出独立的设计规范文档**

## 模块分解规则

在全局架构审批后、逐模块执行前，由 pipeline 执行模块分解：

1. 从 PRB 功能范围表 + 全局架构模块定义表提取模块清单
2. 参考 `modular-vibe-coding` 的 SRP 原则验证模块边界合理性
3. 分析模块间依赖关系，生成依赖图
4. 拓扑排序确定 Wave 划分（无依赖模块归入 Wave 1，依赖 Wave N 的归入 Wave N+1）
5. 同一 Wave 内的模块可并行执行（编码阶段）
6. 产出结构化的模块执行计划文档

## 设计阶段与编码阶段分离

项目级模式下，模块阶段分为两个子阶段：

1. **设计阶段**（Step 10~15）：按 Wave 顺序串行执行，Wave 内并行。Wave N 完成后其 OpenAPI 契约进入**契约冻结**状态，Wave N+1 以冻结契约作为设计输入
2. **全局设计对齐校验**（Step 16~17）：全部模块设计完成后，执行轻量校验（共享设计决策合规 + OpenAPI schema 规范），人类确认后放行
3. **编码阶段**（Step 18~23）：按 Wave 顺序分批进入编码、测试、审查、PR

**设计阶段按 Wave 串行的原因**：Provider 模块先完成设计并冻结契约，Consumer 模块基于冻结契约设计接口调用，从源头预防模块间不一致，而非事后检查修复

## 多 Wave 编排规则

1. **设计阶段按 Wave 串行**：Wave N 全部模块完成设计并审批通过后，其 OpenAPI 契约进入冻结状态，才开始 Wave N+1 的设计
2. **Wave 内并行**：同一 Wave 的模块各自走完整设计流水线（analyze → architect → design-ui），互不阻塞
3. **契约冻结**：Wave N 的 `docs/api-specs/*.yaml` 在全部模块审批通过后标记为 `contract_status: frozen`，后续 Wave 的模块必须以冻结契约作为设计输入
4. **编码阶段按 Wave 执行**：设计对齐校验通过后，按 Wave 顺序进入编码阶段
5. **Wave 间串行**：前一个 Wave 的**被依赖模块** PR 合入 develop 后，依赖方才能开始编码；无被依赖关系的模块不受此限制
6. **Wave 内独立合入**：模块完成后创建独立 PR，无被依赖方可立即合入 develop；有被依赖方需等待依赖模块的 PR 先合入
7. **共享设计决策**：项目级 `/architect` 产出的共享设计决策（统一响应格式、错误码规范、认证方案等），所有模块必须遵循，不得自行定义替代方案

## 多人协作分支规范

- **分支命名**：AI Agent 使用 `ai/<task-id>-<module>` 前缀，人类开发者使用 `human/<name>-<feature>` 前缀
- **冲突预检**：编码完成后自动检测是否有其他并行任务修改了相同文件，重叠时按规则处理（阻塞/警告/放行）
- **develop 同步**：创建 PR 前检查 develop 是否有新提交，有冲突时按决策矩阵处理（自动 rebase / 人工介入）

## Skill 调用纪律

- 流水线中每个阶段必须通过 Skill 工具调用（`/analyze`、`/architect` 等）
- 禁止用 Agent 工具绕过 Skill 直接生成文档或代码
- 模块级 Skill 调用时，必须传入项目级上下文（PRB 路径、全局架构路径、依赖模块 OpenAPI 路径）
