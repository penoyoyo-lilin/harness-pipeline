# 示例项目

本目录包含 Harness Pipeline 流水线的完整产出物示例，供新项目参考。

## user-registration — 用户注册模块

一个完整的流水线闭环示例，展示从需求分析到架构设计的产出物。

### 目录结构

```
user-registration/
├── requirement.md            # 需求文档（/analyze 产出）
├── architecture.md           # 技术架构设计（/architect 产出）
├── openapi.yaml              # OpenAPI 契约（/architect 产出）
└── scaffold/
    ├── backend/user/         # Go Domain 分层脚手架（/code-go 产出结构）
    │   ├── types/            # 类型定义
    │   ├── config/           # 模块配置
    │   ├── repository/       # 数据访问层
    │   ├── service/          # 业务逻辑层
    │   ├── handler/          # HTTP 传输层
    │   └── router/           # 路由注册
    └── frontend/app/         # Next.js 前端脚手架（/code-frontend 产出结构）
        ├── login/            # 登录页
        ├── register/         # 注册页
        └── dashboard/        # 仪表盘
```

### 使用方式

新项目初始化后，可参考此示例理解流水线各阶段的产出物格式和内容深度。
