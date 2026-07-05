# User Domain — Agent 上下文

> 此文件由 Codex 层级合并自动加载，提供 user 模块的局部上下文

## 模块概述
用户模块，负责用户注册、认证、个人信息管理。

## 模块结构
```
internal/domain/user/
├── types/          # User、VerificationCode 实体，DTO，业务错误
├── config/         # 模块配置（验证码 TTL、频率限制等）
├── repository/     # UserRepository、CodeRepository
├── service/        # AuthService、CodeService
├── handler/        # AuthHandler（HTTP 传输层）
└── router/         # 路由注册
```

## 关键约束
- 密码必须 bcrypt 加密（cost=12）
- 验证码通过 Redis 做频率限制（60秒间隔、每日5次上限）
- 同一邮箱/手机号不允许重复注册

## 相关文档
- 需求: `docs/requirements/user-registration.md`
- 架构: `docs/design-docs/user-registration.md`
- 接口契约: `docs/api-specs/user-registration.yaml`
