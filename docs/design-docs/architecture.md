# 系统架构文档

> **注意**：本文档是一个**参考架构示例**，展示了 Harness Pipeline 推荐的分层结构和规范。实际项目可根据需求调整技术选型（如 HTTP 框架、ORM、缓存等），但应遵守分层依赖方向的约束。
>
> 版本：1.0.0
> 更新时间：2026-03-24

---

## 1. 系统概览

基于 Go 后端 + React Next.js 前端的 Web 应用，采用前后端分离架构，通过 RESTful API 通信。

```
┌─────────────────────────────────────────────────────────┐
│                    Client Layer                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  Next.js SSR  │  │  Static CDN  │  │ Mobile H5    │  │
│  └──────┬───────┘  └──────────────┘  └──────┬───────┘  │
└─────────┼──────────────────────────────────┼────────────┘
          │                                  │
          ▼                                  ▼
┌─────────────────────────────────────────────────────────┐
│                    API Gateway (Nginx)                   │
│  • Rate Limiting  • SSL Termination  • Static Serving   │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│                  Go Backend (Gin)                        │
│                                                          │
│  ┌─────────┐  ┌──────────┐  ┌──────────┐               │
│  │ Handler │→│ Service  │→│ Repo     │               │
│  │  Layer  │  │  Layer   │  │  Layer   │               │
│  └─────────┘  └──────────┘  └────┬─────┘               │
│                                     │                    │
│  ┌──────────────────────────────────┼──────────────┐   │
│  │          Middleware Layer          │              │   │
│  │  JWT Auth  • CORS  • Logging  • Recovery       │   │
│  └──────────────────────────────────────────────────┘   │
└──────────┬──────────────────────────────────┬────────────┘
           │                                  │
           ▼                                  ▼
    ┌─────────────┐                    ┌─────────────┐
    │   MySQL     │                    │   Redis     │
    │  (Primary)  │                    │  (Cache)    │
    └──────┬──────┘                    └─────────────┘
           │
           ▼
    ┌─────────────┐
    │   MySQL     │
    │  (Replica)  │
    └─────────────┘
```

---

## 2. 后端架构：Go Domain 分层

### 2.1 分层规则

```
internal/domain/<module>/
├── types/          ← 最内层：Entity、DTO、Error（零外部依赖）
├── config/         ← 模块配置
├── repository/     ← 数据访问：接口定义 + GORM 实现
├── service/        ← 业务逻辑：纯业务，不感知传输层
└── handler/        ← HTTP 传输：请求解析、响应格式化
```

### 2.2 依赖方向（严格单向）

```
handler ──→ service ──→ repository ──→ types
   │           │
   └──→ types  └──→ types
```

### 2.3 模块划分

| 模块 | 路径 | 职责 |
|------|------|------|
| user | internal/domain/user | 用户注册、认证、信息管理 |
| auth | internal/domain/auth | JWT 签发/验证、权限控制 |
| order | internal/domain/order | 订单创建、支付、状态机 |
| product | internal/domain/product | 商品管理、库存 |
| notification | internal/domain/notification | 站内信、推送 |

---

## 3. 前端架构：Next.js App Router

### 3.1 目录结构

```
src/
├── app/                    # Next.js App Router
│   ├── layout.tsx          # 根布局
│   ├── page.tsx            # 首页
│   ├── login/              # 登录页
│   ├── register/           # 注册页
│   ├── dashboard/          # 仪表盘
│   └── api/                # API Routes（BFF 层）
├── components/             # 共享组件
│   ├── ui/                 # 基础 UI 组件（Button、Input、Modal）
│   ├── forms/              # 表单组件
│   └── layouts/            # 布局组件
├── lib/                    # 工具库
│   ├── api.ts              # API Client（Axios 封装）
│   ├── auth.ts             # 认证工具
│   └── utils.ts            # 通用工具函数
├── hooks/                  # 自定义 Hooks
├── styles/                 # 全局样式
├── types/                  # TypeScript 类型定义
└── __tests__/              # 测试文件
```

### 3.2 技术选型

| 技术 | 用途 |
|------|------|
| Next.js 15+ | 框架（App Router、SSR、ISR） |
| React 19+ | UI 库 |
| TypeScript 5+ | 类型安全 |
| Tailwind CSS 4+ | 原子化 CSS |
| shadcn/ui | 组件库 |
| TanStack Query | 数据获取/缓存 |
| Zustand | 客户端状态管理 |
| Axios | HTTP Client |

---

## 4. 通用规范

### 4.1 API 响应格式

```go
// 统一响应结构
type Response struct {
    Code    int         `json:"code"`    // 业务错误码，0=成功
    Message string      `json:"message"` // 人类可读消息
    Data    interface{} `json:"data"`    // 业务数据
}

// 分页响应
type PageResponse struct {
    Code    int         `json:"code"`
    Message string      `json:"message"`
    Data    interface{} `json:"data"`
    Meta    *PageMeta   `json:"meta,omitempty"`
}

type PageMeta struct {
    Page      int   `json:"page"`
    PageSize  int   `json:"page_size"`
    Total     int64 `json:"total"`
    TotalPage int   `json:"total_page"`
}
```

### 4.2 Git 分支策略

```
main (生产)
  └── develop (开发)
       ├── feature/user-registration
       ├── feature/payment
       └── fix/login-bug
```

- `main`：生产分支，仅通过 PR 合入，CI 必须全绿
- `develop`：开发分支，日常集成
- `feature/*`：功能分支，从 develop 拉出
- `fix/*`：修复分支

### 4.3 错误处理原则

- **Go 后端**：Service 层返回业务 error，Handler 层统一转换为 HTTP 响应
- **前端**：API Client 拦截器统一处理，业务层只关心业务逻辑
- **日志**：ERROR 级别必须包含 request_id，方便链路追踪

---

## 5. 部署架构

```
┌──────────────┐
│  GitHub Repo │
└──────┬───────┘
       │ push to main
       ▼
┌──────────────┐
│ GitHub Actions│
│  CI/CD Pipeline
└──────┬───────┘
       │
       ├──→ Build Go Binary → Docker Image → Push to Registry
       │
       └──→ Build Next.js → Docker Image → Push to Registry
              │
              ▼
       ┌──────────────┐
       │  K8s Cluster  │
       │  ┌──────────┐ │
       │  │ Backend  │ │
       │  │ (Go)     │ │
       │  └──────────┘ │
       │  ┌──────────┐ │
       │  │ Frontend │ │
       │  │ (Next.js)│ │
       │  └──────────┘ │
       └──────────────┘
```
