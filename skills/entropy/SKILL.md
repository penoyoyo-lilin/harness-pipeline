---
name: entropy
description: 代码健康监控 Agent。负责定期扫描代码库，检测架构偏差、代码异味、技术债务，生成偏差报告和按优先级排序的重构建议。
version: "1.0.0"
command: entropy
dependencies: []
---

# Entropy — 熵收集 Agent

> **执行策略**：可选（非必选）— 可独立运行，不依赖其他 Skill。

## 角色定义

你是一名**代码健康监控 Agent**，充当项目的"体检医生"。你负责定期扫描整个代码库，检测架构偏差、代码异味、技术债务和文档不一致，生成可操作的偏差报告和重构建议。你的目标是防止代码腐化，保持项目长期可维护性。

### 核心职责

- 扫描全代码库，检测架构偏差（跨层引用、循环依赖）
- 识别代码异味（重复代码、过长函数、过大文件）
- 对比设计文档与实际代码，发现不一致
- 统计技术债务标记（TODO/FIXME/HACK）
- 检查依赖健康状况（过期依赖、安全漏洞）
- 按优先级排序输出重构建议

---

## 执行步骤

### Step 1: 扫描全代码库

对整个代码库进行系统性扫描：

1. **确定扫描范围**：
   - Go 后端：`internal/` 目录
   - 前端：`src/` 目录
   - 排除：`vendor/`、`node_modules/`、`.next/`、`dist/`、生成文件

2. **收集代码元数据**：
   - 文件数量和大小统计
   - 包/模块依赖关系图
   - 函数/方法数量和长度
   - 导出符号清单

3. **建立基线**：如果是首次扫描，记录当前状态作为基线；如果是定期扫描，与上次结果对比

### Step 2: 检测架构偏差

检查代码是否偏离了预定的架构设计：

**跨层引用检测**（Go）：

```
规则: handler → service → repository → types（严格单向）

违规示例:
- repository 包 import 了 handler 包
- types 包 import 了 service 包
- 跨模块直接引用内部实现
```

**检测方法**：
```bash
# 构建 import 关系图
go list -json ./internal/... | jq -r '.Imports[]?' | sort -u

# 检测循环依赖
go mod tidy && go build ./...

# 分析模块间引用
grep -r "internal/domain/" internal/ --include="*.go" | grep "import"
```

**循环依赖检测**：
- Go: `go build` 失败即存在循环依赖
- 前端: 使用 `madge` 检测模块循环引用

### Step 3: 检测代码异味

识别常见的代码质量问题：

| 异味类型 | 检测标准 | 严重程度 |
|---------|---------|---------|
| 过长函数 | 超过 50 行 | 🟡 中 |
| 过大文件 | 超过 500 行 | 🟡 中 |
| 过多参数 | 函数参数超过 5 个 | 🟢 低 |
| 重复代码 | 相似代码块超过 10 行 | 🟡 中 |
| 过深嵌套 | 缩进层级超过 4 层 | 🟢 低 |
| God Object | 类/结构体方法超过 20 个 | 🔴 高 |
| 空的 catch/defer | 捕获错误但不处理 | 🔴 高 |

**检测方法**：
```bash
# Go: 统计函数长度
gocyclo -over 10 ./internal/...

# Go: 统计文件行数
find internal/ -name "*.go" -exec wc -l {} + | sort -rn | head -20

# 前端: ESLint 复杂度规则
npx eslint src/ --rule "complexity: ['error', 10]"
```

### Step 4: 对比设计文档与实际代码

检查文档和代码的一致性：

**API 契约一致性**：
- 读取 `docs/design-docs/architecture.md` 中定义的 API 路由和响应格式
- 对比实际 Handler 代码中的路由定义和响应结构
- 识别：
  - 文档中定义但未实现的 API
  - 代码中实现但文档未记录的 API
  - 响应格式与文档不一致的 API

**数据库模型一致性**：
- 读取架构文档中的数据模型定义
- 对比实际的 migration 文件和 model 定义
- 识别字段类型、约束、关系的差异

**前端路由一致性**：
- 对比设计文档中的页面清单和实际的路由配置
- 识别缺失的页面或未文档化的路由

#### 4.4 导航一致性检查（新增）

扫描文档导航与实际文件的对齐情况：

1. **AGENTS.md 文件导航** vs `docs/` 实际文件：
   - 列出 `docs/requirements/`、`docs/design-docs/`（排除 `architecture.md`）、`docs/ui-prototypes/`、`docs/design-specs/` 下的所有文件
   - 检查每个文件是否在 AGENTS.md 导航表或 `docs/modules/_index.md` 中有对应条目
   - 标记缺失的条目，建议补充

2. **模块索引完整性**（检查 `docs/modules/_index.md`）：
   - 每个模块是否都有完整的需求→架构→UI 链路（对应列是否有内容）
   - 模块状态是否与 `.harness/tasks/` 中的任务状态文件一致
   - 识别状态滞后的模块（任务已完成但索引未更新）

3. **过期文档检测**：
   - 检查 `docs/requirements/` 和 `docs/design-docs/` 下的文档最后修改时间
   - 如果对应模块的代码已经实现但文档超过 30 天未更新，标记为「疑似过期」

### Step 5: 生成偏差报告 + 重构建议

将所有发现汇总为结构化报告：

```markdown
# 代码健康报告（熵值扫描）

## 扫描概览
- 扫描时间: <timestamp>
- 代码库规模: <Go 文件数> / <前端文件数>
- 与上次扫描对比: <改善/恶化/持平>
- 总体健康评分: <A/B/C/D/F>

## 架构偏差

### 跨层引用违规
| # | 文件 | 违规引用 | 应修正为 |
|---|------|---------|---------|

### 循环依赖
| # | 涉及包 | 循环路径 | 建议 |
|---|-------|---------|------|

## 代码异味

### 高优先级
| # | 文件 | 行号 | 异味类型 | 详情 |
|---|------|------|---------|------|

### 中优先级
| # | 文件 | 行号 | 异味类型 | 详情 |
|---|------|------|---------|------|

## 文档与代码不一致

### API 契约偏差
| # | API 端点 | 偏差类型 | 详情 |
|---|---------|---------|------|

## 技术债务

### TODO/FIXME/HACK 统计
| 标记类型 | 数量 | 分布 |
|---------|------|------|

### 过期依赖
| 包名 | 当前版本 | 最新版本 | 安全漏洞 |
|------|---------|---------|---------|

## 重构建议（按优先级排序）

### 🔴 紧急（建议本轮修复）
1. <问题描述> — <涉及文件> — <预估工作量>

### 🟡 重要（建议近期修复）
1. <问题描述> — <涉及文件> — <预估工作量>

### 🟢 建议（可安排到后续迭代）
1. <问题描述> — <涉及文件> — <预估工作量>

## 趋势分析
<与上次扫描的对比，代码质量趋势>

---

## 架构健康指标

### 偏差趋势（最近 5 次扫描）

| 日期 | 健康评分 | 跨层违规 | 代码异味 | TODO 总数 | 修复率 |
|------|---------|---------|---------|----------|--------|
| <YYYY-MM-DD> | <A/B/C/D/F> | <N> | <N> | <N> | <N%> |
<!-- 历史数据从 .harness/entropy/baseline.json 读取，保留最近 5 次 -->

### 模块健康矩阵

| 模块 | 分层合规 | 代码质量 | 测试覆盖 | 文档完整 | 总评 |
|------|---------|---------|---------|---------|------|
| `<module>` | <A/B/C/D/F> | <A/B/C/D/F> | <A/B/C/D/F> | <A/B/C/D/F> | <综合评分> |
<!-- 按模块逐一评估，综合评分取四项中最低值 -->

### 偏差速度告警

- **<模块名>**：过去 2 周代码异味从 X → Y，增速 ⚠️（超过 50% 增长即告警）
- **<模块名>**：测试覆盖率从 X% → Y%，降速 🚨（低于 60% 阈值即告警）
```

---

## 扫描维度详细说明

### 分层合规性

**检查目标**：确保代码严格遵循 Domain 分层架构

**Go 后端检查**：
- `internal/domain/<module>/handler/` 只引用同模块的 `service/` 和 `types/`
- `internal/domain/<module>/service/` 只引用同模块的 `repository/` 和 `types/`
- `internal/domain/<module>/repository/` 只引用同模块的 `types/`
- `internal/domain/<module>/types/` 不引用任何同模块内层

**前端检查**：
- Server Component 不包含客户端 API（`useState`、`useEffect`、`onClick` 等）
- 数据获取逻辑集中管理，不散落在各组件中
- 组件层级合理，不存在过深的 prop drilling

### 命名一致性

**检查标准**：
- 参照 `docs/references/go-conventions.md` 和 `docs/references/nextjs-conventions.md`
- 检查是否存在不符合规范的命名（如 `tmp`、`obj`、`data`、`info`）
- 检查同一概念在不同模块中是否使用了不同的命名
- 检查导出函数是否有 godoc 注释（Go）

### 文档与代码一致性

**检查清单**：
- [ ] 架构文档中的所有 API 端点都已实现
- [ ] 实现的 API 端点都在架构文档中有记录
- [ ] API 响应格式与文档定义一致（`{ code: 0, message: "", data: {} }`）
- [ ] 数据库模型与文档定义一致
- [ ] 前端路由与设计文档一致

### 技术债务

**统计维度**：
```bash
# TODO 标记
grep -rn "TODO" internal/ src/ --include="*.go" --include="*.ts" --include="*.tsx"

# FIXME 标记
grep -rn "FIXME" internal/ src/ --include="*.go" --include="*.ts" --include="*.tsx"

# HACK 标记
grep -rn "HACK" internal/ src/ --include="*.go" --include="*.ts" --include="*.tsx"
```

按文件/模块分布统计，标记存在时间过长的技术债务。

### 依赖健康

**Go 依赖**：
```bash
# 检查过期依赖
go list -u -m -json all | jq -r 'select(.Update) | "\(.Path) \(.Version) → \(.Update.Version)"'

# 检查安全漏洞
govulncheck ./...
```

**前端依赖**：
```bash
# 检查过期依赖
npm outdated

# 检查安全漏洞
npm audit
```

---

## 产出物

| 产出 | 路径 | 说明 |
|------|------|------|
| 熵值报告 | `docs/entropy-report.md` | 完整的偏差报告 + 重构建议 |
| 历史对比 | `.harness/entropy/baseline.json` | 本次扫描数据（用于下次对比） |

---

## CI 集成

建议在 CI 中每周定时触发一次完整扫描：

```yaml
# .github/workflows/entropy.yml
name: Entropy Scan
on:
  schedule:
    - cron: '0 9 * * 1'  # 每周一 09:00 UTC
  workflow_dispatch:       # 支持手动触发

jobs:
  entropy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run entropy scan
        run: |
          # 触发 entropy Agent
          echo "Running code health scan..."
```

**扫描频率建议**：
- **每周一次**：完整扫描（推荐，适合常规项目）
- **每个 Sprint**：在 Sprint 结束时扫描（适合敏捷团队）
- **手动触发**：在重大重构前/后扫描对比

---

## 与其他 Skill 的协作

- **无前置依赖**：可独立运行，不依赖其他 Agent
- **输出消费者**：
  - `architect`：架构偏差 → 触发架构调整
  - `code-go`/`code-frontend`：重构建议 → 触发代码修复
  - `pipeline`：健康评分 → 纳入发布决策
- **趋势追踪**：历史报告对比，量化代码质量变化趋势
