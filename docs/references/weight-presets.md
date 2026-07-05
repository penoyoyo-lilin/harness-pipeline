# Weight Preset 规范

> **作用**：控制流水线的流程重量。同一套方法论，按需求规模匹配不同的审批节点数和门控强度，避免小需求被迫走重型流程。
>
> Weight 由 pipeline Step 1 的 Weight Detection 自动判定，人类可覆盖。

---

## 1. 三档 Preset

| Preset | 定位 | 审批节点数 | 硬门控数 | 适用场景 |
|--------|------|-----------|---------|---------|
| `light` | 轻量 | 2 | 1 | 原型/PoC/个人项目/单模块小改动 |
| `standard` | 标准 | 3 | 3 | 中型项目、模块级需求、增量迭代 |
| `heavy` | 重量 | 8 | 6 | 多模块业务系统、首次架构、修改冻结契约 |

---

## 2. 各档启用的 Step 与门控

### light

| 流水线阶段 | 是否启用 | 说明 |
|-----------|---------|------|
| Step 0a 任务巡检 | ✅ | 始终启用 |
| Step 0b 基线检查 | ❌ | 跳过 |
| Step 1 Weight Detection | ✅ | 始终启用 |
| 项目级阶段（Step 2-9.5） | ❌ | 跳过，直接走模块级 |
| Step 10 /analyze（模块级） | ✅ | — |
| Step 11 ⏸需求确认 | ✅ | **审批节点 1** |
| Step 12 /architect | ✅ | — |
| Step 13 ⏸架构审批 | ✅ | **审批节点 2** |
| Step 13.5 跨模块影响 | ❌ | 跳过 |
| Step 14 /design-ui | ❌ | 跳过（light 不做 UI 原型） |
| Step 15 ⏸设计审批 | ❌ | 跳过 |
| Step 15.1 契约冻结 | ❌ | 跳过 |
| Step 16-17 设计对齐 | ❌ | 跳过 |
| Step 18 编码 | ✅ | — |
| Step 18.5 提交范围检查 | ❌ | 跳过 |
| Step 18.6 冲突预检 | ❌ | 跳过 |
| Step 19 contract-sync | ❌ | 跳过 |
| Step 20 /test | ✅ | **硬门控 1**（仅单元测试） |
| Step 21 /review | ❌ | 跳过（可选手动触发） |
| Step 22 集成测试 | ❌ | 跳过 |
| Step 22.5 develop 同步 | ❌ | 跳过 |
| Step 23 创建 PR | ✅ | 仅要求 test 通过 |

**文档产出**：`docs/requirements/<module>.md` + `docs/design-docs/<module>.md`，不产出 PRB/模块分解/全局设计规范/HTML 原型。

### standard

| 流水线阶段 | 是否启用 | 说明 |
|-----------|---------|------|
| Step 0a-0b | ✅ | 基线检查启用 |
| Step 1 Weight Detection | ✅ | — |
| 项目级阶段（Step 2-9.5） | ❌ | 跳过，走模块级 |
| Step 10-11 /analyze + 需求确认 | ✅ | **审批节点 1** |
| Step 12-13 /architect + 架构审批 | ✅ | **审批节点 2** |
| Step 13.5 跨模块影响 | ✅ | 有跨模块依赖时启用 |
| Step 14-15 /design-ui + 设计审批 | ✅ | **审批节点 3**（有 UI 时） |
| Step 15.1 契约冻结 | ❌ | 模块级无需 |
| Step 16-17 设计对齐 | ❌ | 模块级无需 |
| Step 18 编码 | ✅ | — |
| Step 18.5 提交范围检查 | ✅ | **硬门控 1** |
| Step 18.6 冲突预检 | ✅ | 多人协作时启用 |
| Step 19 contract-sync | ✅ | **硬门控 2** |
| Step 20 /test | ✅ | **硬门控 3** |
| Step 21 /review | ⚠️ | 软门控，跳过需记录原因 |
| Step 22 集成测试 | ✅ | **硬门控** |
| Step 22.5 develop 同步 | ✅ | 多人协作时启用 |
| Step 23 创建 PR | ✅ | — |

**文档产出**：模块需求 + 模块架构 + OpenAPI 契约 + HTML 原型（有 UI 时）。

### heavy

全部 Step 启用，即当前默认的项目级两阶段流水线。8 个审批节点 + 6 个硬门控，详见 `pipeline/SKILL.md`。

**文档产出**：完整体系 — PRB + 全局架构 + 全局设计规范 + 模块执行计划 + 每模块需求/架构/OpenAPI/原型 + 设计对齐报告。

---

## 3. Weight Detection 算法（pipeline Step 1 执行）

### 第一层：显式信号（硬规则，优先级最高，从高到低短路）

| # | 信号 | 来源 | → heavy | → standard | → light |
|---|------|------|---------|-----------|---------|
| 1 | 是否有全局架构文档 | `docs/design-docs/architecture.md` 存在且非模板占位 | 无 → heavy | 有 | 有 |
| 2 | 涉及业务域数 | 需求文本 + 已有模块索引 | ≥3 | 2 | 1 |
| 3 | 是否修改已冻结契约 | 任务 YAML `contract_status: frozen` | 是 → heavy | — | — |
| 4 | 是否新增模块 | 需求是否命中 `_index.md` 已有模块 | 多个新模块 | 单新模块 | 仅改现有 |
| 5 | 影响已有模块数 | 需求文本 grep 模块名 | ≥3 | 2 | 1 |
| 6 | 项目阶段 | `.harness/tasks/` 是否有 completed 任务 | 首次初始化 | 增量迭代 | 热修/补丁 |

**判定逻辑**（伪代码）：

```
detectWeight(req, projectState):
    # 硬规则，任一命中即定档，从高到低短路
    if not projectState.hasGlobalArch:          return HEAVY
    if countBusinessDomains(req) >= 3:          return HEAVY
    if modifiesFrozenContract(req, state):      return HEAVY

    if countBusinessDomains(req) == 2:          return STANDARD
    if isNewModule(req, state):                 return STANDARD
    if countAffectedModules(req) == 2:          return STANDARD

    return LIGHT
```

### 第二层：隐式信号（AI 语义推断，仅在显式信号不足时介入）

`/analyze` 在产出需求文档时，附带 Weight 评估段：

```markdown
## Weight 评估

**建议**: standard
**置信度**: 高/中/低

### 显式信号
- 涉及 N 业务域 → heavy/standard/light
- 新增/修改 N 模块 → ...
- 修改冻结契约 → yes/no

### 隐式信号
- 可逆性: 改样式(偏light) / 改数据模型(偏heavy)
- 影响半径: 单文件(light) / 跨模块(heavy)
- 失败成本: 界面bug(light) / 数据损坏(heavy)
- 需求确定性: 明确(light) / 需设计(heavy)

### 冲突裁决
显式优先，隐式补位。若用户认为评估偏高/偏低，可覆盖。
```

### 第三层：人类覆盖（最终决定权）

pipeline Step 1 末尾向人类展示判定结果并允许覆盖：

```
📊 Weight 判定: standard (置信度: 高)
   依据: 涉及 2 业务域 + 新增 1 模块
   流程: 3 审批节点 + 3 硬门控 + contract-sync + 集成测试

是否调整?
  [1] 接受 standard (推荐)
  [2] 降为 light
  [3] 升为 heavy
```

---

## 4. 中途升级规则

流水线执行中若发现复杂度被低估（如 `/architect` 发现牵涉 3 个模块）：

- **允许升级**：自动提升 weight，补做缺失的门控
- **不允许降级**：已承诺的门控不可跳过

这保证"门控只会多不会少"，避免 AI 为走捷径自行降级。

---

## 5. 项目级配置

项目根 `.harness/pipeline.yaml`（可选，覆盖自动判定）：

```yaml
# 强制指定 weight（不指定则由 Step 1 自动判定）
weight: standard

# 或设为 auto（默认），由 Weight Detection 自动判定
weight: auto
```

若显式指定 `weight`，Step 1 跳过自动判定直接使用该值（但仍展示给人类确认）。

---

## 6. pipeline 如何按 weight 过滤 Step

`pipeline/SKILL.md` 的每个 Step 增加 `weight_gate` 标注：

```markdown
#### Step 19：执行 contract-sync
> weight_gate: standard, heavy（light 跳过）
```

pipeline 启动时根据当前 weight 过滤：weight 不在 gate 列表中的 Step 自动跳过并记录日志"skipped due to weight=light"。
