# Stack Profile 规范

> **作用**：Profile 是框架与具体技术栈之间的适配层。方法论（契约先行、Wave 拓扑、状态机）栈无关，Profile 负责声明"本栈怎么落地"。
>
> 流水线启动时读取 `.harness/pipeline.yaml` 中的 `stack` 字段定位 Profile，按 Profile 里的声明动态拼装目录结构、调用哪些 code skill、用什么脚本做基线检查和契约同步。

---

## 1. Profile 的定位

```
┌─────────────────────────────────────────────┐
│   方法论层（栈无关，固定）                      │
│   analyze → architect → design-ui →           │
│   code → contract-sync → test → review → PR   │
└──────────────────┬──────────────────────────┘
                   │ 读取 profile 动态装配
                   ▼
┌─────────────────────────────────────────────┐
│   Profile 适配层（栈相关，可插拔）              │
│   profile.yaml + code skills + scripts        │
└──────────────────┬──────────────────────────┘
                   │
        ┌──────────┼──────────┐
        ▼          ▼          ▼
   go-gin-react  python-    node-nestjs-
                  fastapi-   react
                  vue
```

**原则**：
- 方法论 skill（analyze / architect / design-ui / test / review / entropy / pipeline）栈中立，不因 profile 变化
- 编码 skill（code-backend / code-frontend）栈相关，每个 profile 自带
- 流水线不硬编码栈名，一律读 profile 字段

---

## 2. profile.yaml 字段规范

每个 profile 目录下必须有 `profile.yaml`，字段如下：

```yaml
# profile.yaml
name: go-gin-react                    # 唯一标识，与目录名一致
display_name: "Go (Gin) + React"      # 人类可读名称
description: "Go 后端 Domain 分层 + Next.js/Vite 前端"

# ─── 后端声明（无后端项目此段置 null）───
backend:
  language: go                         # go | python | node | rust | null
  code_skill: code-backend             # 对应 stacks/<profile>/code-backend/SKILL.md
  module_dir: "internal/domain/{module}"   # 模块根路径，{module} 为占位符
  layering: "types→config→repository→service→handler→router"  # 分层顺序，用于基线检查
  conventions_ref: "docs/references/go-conventions.md"         # 编码规范文档路径（相对项目根）
  baseline_check: "scripts/baseline-check.sh"   # 分层依赖方向检查脚本（相对 profile 目录）
  contract_sync: "scripts/contract-sync.sh"     # 后端路由↔契约 检查脚本
  integration_test: "scripts/integration-test.sh"  # 集成测试脚本
  build_cmd: "go build ./..."          # 编译验证命令
  lint_cmd: "golangci-lint run"        # lint 命令
  coverage:
    service: 80
    handler: 70

# ─── 前端声明（无前端项目此段置 null）───
frontend:
  language: typescript
  code_skill: code-frontend
  module_dir: "src/app/{module}"
  conventions_ref: "docs/references/nextjs-conventions.md"
  integration_test: "scripts/integration-test-frontend.sh"
  build_cmd: "npm run build"
  lint_cmd: "npx next lint"

# ─── 契约格式声明 ───
contract:
  format: openapi                      # openapi | grpc | graphql
  path: "docs/api-specs/{module}.yaml" # 契约文件路径模式
  shared_path: null                    # 项目级共享契约路径（无则 null）

# ─── UI 能力声明 ───
ui: optional                           # required | optional | none

# ─── 目录初始化模板（init.sh 按 profile 装配）───
scaffold:
  dirs:                                # 需创建的目录（相对项目根）
    - "internal/domain"
    - "src/app"
    - "docs/api-specs"
  files: []                            # 需复制的文件（相对 profile 目录）

# ─── 能力开关（pipeline 据此决定跳过哪些 Step）───
capabilities:
  has_backend: true
  has_frontend: true
  has_contract: true                   # false 时 contract-sync Step 自动跳过
  has_ui: true                         # false 时 design-ui Step 自动跳过
```

---

## 3. Profile 目录结构

```
stacks/<profile-name>/
├── profile.yaml              # 栈声明（必需）
├── code-backend/             # 后端编码 skill（has_backend=true 时必需）
│   └── SKILL.md
├── code-frontend/            # 前端编码 skill（has_frontend=true 时必需）
│   └── SKILL.md
└── scripts/                  # 栈相关脚本
    ├── baseline-check.sh     # 分层依赖方向检查
    ├── contract-sync.sh      # 后端路由↔契约 检查
    ├── integration-test.sh   # 后端集成测试
    └── integration-test-frontend.sh  # 前端集成测试（如有前端）
```

**脚本契约**：所有脚本接收项目根目录作为第一个参数，退出码 0=通过、非 0=失败，失败时 stderr 输出原因。报告写入 `.harness/reports/`。

---

## 4. pipeline 如何消费 Profile

`pipeline/SKILL.md` 的关键改动点（Step 2 落地）：

| 原硬编码 | 改为读 profile |
|---------|---------------|
| Step 18: `/code-go + /code-frontend` 并行 | 读 `backend.code_skill` + `frontend.code_skill`，任一为 null 则跳过 |
| Step 0b: `grep repository internal/domain/*/handler/` | 调用 `backend.baseline_check` |
| Step 19: `scripts/contract_sync.sh` | 调用 `backend.contract_sync` |
| Step 22: testcontainers + Go + MSW | 调用 `backend.integration_test` + `frontend.integration_test` |
| Step 18.5: 按 `internal/domain/<module>/` 分类 | 读 `backend.module_dir` / `frontend.module_dir` |
| `code-go` / `code-frontend` 命名 | 读 `code_skill` 字段，动态引用 |

---

## 5. 新增 Profile 的检查清单

编写新 profile 时逐项确认：

- [ ] `profile.yaml` 字段齐全，`name` 与目录名一致
- [ ] `capabilities` 与 `backend`/`frontend`/`contract`/`ui` 段落一致（声明 has_backend=false 则 backend 段必须 null）
- [ ] `code-backend/SKILL.md`（如存在）的产出物路径与 `module_dir` 一致
- [ ] 所有 scripts 可独立执行，退出码语义正确
- [ ] 用新 profile 跑一遍模块级流水线（light weight），无栈相关报错

**关键验证**：写第二个 profile 时若被迫回头改本规范或 pipeline 核心，说明抽象不够，需回补。
