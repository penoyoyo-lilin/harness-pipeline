# Harness Pipeline

> AI Agent 团队协作流水线框架 —— 把"契约先行 + Wave 拓扑 + 状态机"这套产研方法论做成可开箱即用的 Skill 流水线，支持多技术栈。

## 这是什么

一套给 AI Agent（Claude Code / ZCode 等）使用的产研流水线框架。它把需求→设计→编码→测试→审查→PR 的完整流程拆成 8 个可组合的 Skill，通过任务状态机 + 人类审批节点 + 质量门控，让 AI Agent 团队像人类团队一样协作交付。

**核心特征**：

- **方法论栈无关**：契约先行、Wave 拓扑排序、设计对齐校验、熵值监控——这些机制与语言无关
- **技术栈可插拔**：通过 Profile 机制适配不同栈（Go+React、Python+Vue、Node+React...），新增栈只需写一个 profile 目录
- **流程重量分档**：light / standard / heavy 三档，AI 自动判定需求规模，匹配对应的审批节点和门控强度
- **三层契约同步**：协议层 / 探测层 / 比对层分离，gRPC、GraphQL、OpenAPI 都能用同一套比对逻辑

## 快速开始

### 用框架初始化新项目

```bash
# 克隆本仓库
git clone git@github.com:penoyoyo-lilin/harness-pipeline.git

# 初始化一个 Go + React 项目
bash harness-pipeline/scripts/init.sh /path/to/my-project --stack go-gin-react

# 或初始化一个 Python + Vue 项目
bash harness-pipeline/scripts/init.sh /path/to/my-project --stack python-fastapi-vue
```

初始化后，新项目会得到：
- `.claude/skills/` — 流水线 Skill 定义（方法论 + 当前 profile 的编码 skill）
- `.harness/profile.yaml` — 本项目的栈声明
- `.harness/scripts/` — 栈相关的检查脚本（基线检查、契约同步、集成测试）
- `docs/` — 文档体系骨架（模板、规范、目录结构）

### 在 Claude Code / ZCode 中使用

初始化完成后，在项目目录下启动 Claude Code 或 ZCode，直接对话：

```
/pipeline 实现用户注册功能，支持邮箱和手机号
```

或单步调用：

```
/analyze 需求描述                    # 需求分析
/architect 需求文档路径               # 架构设计 + OpenAPI 契约
/design-ui 需求描述                   # UI 原型设计
/code-backend 架构设计路径            # 后端编码（按 profile）
/code-frontend 架构设计路径           # 前端编码（按 profile）
/test 代码路径                        # 测试
/review 代码路径                      # 代码审查
/entropy                              # 代码健康扫描
```

### 安装到全局（可选）

如果你想在任何项目都能用 `/pipeline` 等命令，而不必每次初始化：

```bash
bash harness-pipeline/scripts/install-skills-to-trae.sh
```

会把 Skill 安装到 `~/.claude/skills/`（ZCode 通过符号链接自动跟随），profile 安装到 `~/.claude/stacks/`。

## 流水线全景

```
用户需求
  → /analyze           需求拆解 + 验收标准
  → ⏸ 人类确认需求
  → /architect         技术方案 + 数据模型 + OpenAPI 契约
  → ⏸ 人类审批架构
  → /design-ui         UI 原型（有 UI 需求时）
  → ⏸ 人类确认设计
  → /code-backend      后端编码（按 profile）
  → /code-frontend     前端编码（按 profile）
  → contract-sync      契约三层一致性检查
  → /test              单元测试 + 集成测试（硬门控）
  → /review            代码审查 + 架构合规
  → PR                 合入 develop
```

**项目级模式**（多模块需求）额外有：PRB → 全局架构 → 全局设计规范 → 模块分解 → 按 Wave 串行设计 → 全局设计对齐 → 按 Wave 编码。

## 目录结构

```
harness-pipeline/
├── AGENTS.md                  # Agent Team 总调度协议
├── CLAUDE.md                  # 流水线执行指令（分支判断规则）
├── skills/                    # 方法论 Skill（栈中立）
│   ├── registry.yaml          # Skill 注册表（单一真相源）
│   ├── analyze/               # 需求分析
│   ├── architect/             # 架构设计
│   ├── design-ui/             # UI 设计
│   ├── pipeline/              # 流水线编排（Lead Agent）
│   ├── test/                  # 测试
│   ├── review/                # 代码审查
│   ├── entropy/               # 代码健康监控
│   ├── code-go/               # 旧版 Go 编码 skill（兼容保留）
│   ├── code-frontend/         # 旧版前端编码 skill（兼容保留）
│   └── modular-vibe-coding/   # 模块化编码方法论
├── stacks/                    # 技术栈 Profile（可插拔）
│   ├── PROFILE-SPEC.md        # profile.yaml 字段规范
│   ├── lib/                   # 栈无关共享库
│   │   ├── CONTRACT-SYNC-SPEC.md
│   │   └── contract-diff.sh   # 契约比对层
│   ├── go-gin-react/          # Go (Gin) + React profile
│   │   ├── profile.yaml
│   │   ├── code-backend/SKILL.md
│   │   ├── code-frontend/SKILL.md
│   │   └── scripts/           # baseline-check / contract-sync / integration-test
│   └── python-fastapi-vue/    # Python (FastAPI) + Vue profile
│       ├── profile.yaml
│       ├── code-backend/SKILL.md
│       ├── code-frontend/SKILL.md
│       └── scripts/
├── scripts/                   # 框架脚本
│   ├── init.sh                # 项目初始化（支持 --stack）
│   ├── install-skills-to-trae.sh  # 安装到全局
│   └── contract_sync.sh       # 契约同步入口
├── docs/                      # 文档体系
│   ├── templates/             # 需求/架构/PRB/UI 模板
│   ├── references/            # 编码规范 + weight-presets 规范
│   ├── design-docs/           # 参考架构
│   └── entropy-report.md      # 熵值报告（自动生成）
├── examples/                  # 完整示例（user-registration）
└── projects/                  # 实际项目工作区（独立 git 仓库，不入库）
```

## 可用 Profile

| Profile | 后端 | 前端 | 状态 |
|---------|------|------|------|
| `go-gin-react` | Go (Gin) + Domain 分层 | Next.js / Vite + React | ✅ 可用 |
| `python-fastapi-vue` | Python (FastAPI) 分层 | Vue 3 + TypeScript | ✅ 可用 |

新增 Profile：复制一个现有 profile 目录，改 `profile.yaml` + 编码 SKILL.md + 脚本，参考 `stacks/PROFILE-SPEC.md`。

## Weight Preset

AI 根据需求规模自动选择流程重量：

| Preset | 审批节点 | 硬门控 | 适用场景 |
|--------|---------|--------|---------|
| `light` | 2 | 1 | 原型 / PoC / 单模块小改 |
| `standard` | 3 | 3 | 中型项目 / 模块级需求 / 增量迭代 |
| `heavy` | 8 | 6 | 多模块业务系统 / 首次架构 / 修改冻结契约 |

判定逻辑：显式信号（业务域数、模块数、是否动冻结契约）→ 隐式信号（可逆性、影响半径）→ 人类覆盖。详见 `docs/references/weight-presets.md`。

## 核心机制

### 契约先行 + Wave 冻结
项目级模式下，Wave N 的 OpenAPI 契约审批后冻结，Wave N+1 必须以冻结契约作为设计输入，从源头预防模块间不一致。

### 三层契约同步
```
探测层（栈相关）       协议层（栈相关）       比对层（栈无关）
extract-routes.sh  →  解析 OpenAPI/proto  →  contract-diff.sh
提取后端实际路由       提取契约声明的路径       set diff + 报告
```

### 任务状态机
`.harness/tasks/<task-id>.yaml` 追踪每个任务的生命周期：`pending → in_progress → waiting_approval → completed`，支持暂停、恢复、退回、失败重试。

### 质量门控
- **硬门控**：contract-sync / test / 集成测试 —— 不通过不可进入下一阶段
- **软门控**：review —— 跳过需记录原因
- **人类审批节点**：需求 / 架构 / 设计 —— 流水线暂停等待确认

## 适配的 AI 工具

| 工具 | 支持方式 |
|------|---------|
| Claude Code | 读取 `.claude/skills/`（项目级或全局） |
| ZCode | 通过 `~/.zcode/skills/` 符号链接跟随 `~/.claude/skills/` |
| 其他支持 SKILL.md 规范的工具 | 复制 `.claude/skills/` 到对应目录 |

## 分支策略

```
main (生产) ← develop (开发) ← feature/* (功能)
```

AI Agent 生成的分支用 `ai/<task-id>-<module>` 前缀，人类开发者用 `human/<name>-<feature>` 前缀。

## 许可

本框架供个人/团队内部使用。如需开源发布，请添加合适的 LICENSE。

---

*这套框架的价值在于方法论本身——契约先行、设计对齐、熵值监控这些机制可以抽离到任何项目。把它当参考架构和流程蓝本来看，比当通用脚手架来看更准确。*
