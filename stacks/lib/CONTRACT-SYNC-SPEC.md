# Contract Sync 三层架构规范

> **作用**：把契约一致性检查拆成协议层、探测层、比对层，使核心比对逻辑栈无关。
> 各 profile 只需提供探测层脚本（提取后端路由 + 提取前端调用），复用统一的比对层。

---

## 1. 三层划分

```
┌─────────────────────────────────────────────┐
│  比对层（栈无关，固定）                        │
│  lib/contract-diff.sh                        │
│  输入：两份路径列表 → 输出：差异报告 + 退出码  │
└──────────────────┬──────────────────────────┘
                   │ 调用
        ┌──────────┴──────────┐
        ▼                     ▼
┌───────────────┐    ┌───────────────┐
│  探测层（栈相关）│    │  协议层（栈相关）│
│  extract-      │    │  解析 OpenAPI/ │
│  routes.sh     │    │  proto/GraphQL │
│  extract-      │    │  提取 paths     │
│  calls.sh      │    │                │
└───────────────┘    └───────────────┘
```

### 协议层
- 解析契约文件（OpenAPI YAML / gRPC proto / GraphQL schema）
- 提取声明的路径/方法列表，输出为统一中间格式
- 每种契约格式一个解析器，由 profile 的 `contract.format` 字段选择

### 探测层
- `extract-routes.sh`：从后端代码提取实际注册的路由（grep 路由注册语句）
- `extract-calls.sh`：从前端代码提取 API 调用（grep fetch/axios 调用）
- 每个 profile 自带，输出统一中间格式

### 比对层
- `contract-diff.sh`：接收两份路径列表，做 set diff，输出差异报告
- 完全栈无关，所有 profile 共用

---

## 2. 统一中间格式

探测层和协议层都输出 **每行一条路径** 的纯文本，格式：

```
METHOD /api/v1/path
```

示例：
```
GET /api/v1/users
POST /api/v1/users
GET /api/v1/users/{id}
```

比对层对这份文本做 `comm` / `diff` 操作。

---

## 3. 目录结构

```
stacks/
├── lib/                          # 共享库（栈无关）
│   └── contract-diff.sh          # 比对层（所有 profile 共用）
└── <profile>/
    └── scripts/
        ├── contract-sync.sh      # 编排层：调用探测+协议+比对
        ├── extract-routes.sh     # 探测层：提取后端路由
        └── extract-calls.sh      # 探测层：提取前端调用（可选）
```

---

## 4. 各脚本契约

### `lib/contract-diff.sh`（比对层，栈无关）

```bash
# 用法: contract-diff.sh <left-file> <right-file> <left-label> <right-label> <report-file>
# 输入: 两个每行一条路径的文本文件
# 输出: 差异报告写入 report-file，退出码 0=一致 1=有漂移
```

### `<profile>/scripts/extract-routes.sh`（探测层，栈相关）

```bash
# 用法: extract-routes.sh <project-dir>
# 输出: stdout 每行一条 "METHOD /path"，退出码 0
# 每个 profile 用自己的 grep 模式（Go: r.GET, Python: @router.get, ...）
```

### `<profile>/scripts/contract-sync.sh`（编排层）

```bash
# 用法: contract-sync.sh <project-dir> [openapi-path] [report-path]
# 编排逻辑:
#   1. 调用 extract-routes.sh → 后端路由列表
#   2. 解析 OpenAPI（协议层）→ 契约路径列表
#   3. 调用 lib/contract-diff.sh → 差异报告
```

---

## 5. 新增 profile 的 contract-sync 检查清单

- [ ] 提供 `extract-routes.sh`，输出统一中间格式
- [ ] `contract-sync.sh` 调用 `lib/contract-diff.sh` 做比对（不自己实现 diff）
- [ ] 契约格式与 `profile.yaml` 的 `contract.format` 一致
