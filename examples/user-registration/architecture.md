# 用户注册模块 - 技术架构设计

> 模块：user-registration  
> 版本：1.0.0  
> 作者：Architect Agent  
> 依赖：docs/requirements/user-registration.md  
> 接口契约：docs/api-specs/user-registration.yaml  
> 状态：✅ 已审批

---

## 1. 架构概述

用户注册模块采用 **Go Domain 分层架构**，分为以下层次：

```
internal/domain/user/
├── types/          # 类型定义（DTO、Entity、Error）
│   ├── entity.go       # 数据库实体
│   ├── dto.go          # 请求/响应 DTO
│   └── errors.go       # 业务错误码
├── config/         # 模块配置
│   └── config.go       # 验证码有效期、频率限制等
├── repository/     # 数据访问层（只依赖 types）
│   ├── user_repo.go    # 用户仓储接口 + 实现
│   └── code_repo.go    # 验证码仓储接口 + 实现
├── service/        # 业务逻辑层（只依赖 types + repository）
│   ├── auth_service.go # 认证服务（注册/登录/验证）
│   └── code_service.go # 验证码服务（生成/校验/发送）
├── handler/        # HTTP 传输层（只依赖 types + service）
│   └── auth_handler.go # HTTP Handler + 路由注册
└── router/         # 路由注册
    └── router.go       # 路由汇总
```

### 依赖方向（严格遵守）

```
handler → service → repository → types
   ↓         ↓
 config    config
```

**禁止**：内层引用外层。例如 repository 不得 import service 或 handler。

---

## 2. 技术选型

| 组件 | 选型 | 理由 |
|------|------|------|
| HTTP 框架 | Gin | 高性能、生态成熟、团队熟悉 |
| ORM | GORM | 类型安全、自动迁移、支持多种数据库 |
| 缓存 | Redis | 验证码频率限制、Session 存储 |
| 密码加密 | bcrypt (cost=12) | 行业标准，抗彩虹表 |
| JWT | golang-jwt | 无状态认证 |
| 邮件 | net/smtp + 模板 | Go 标准库，无需额外依赖 |
| 短信 | 阿里云 SMS SDK | 国内主流，可靠性高 |
| 日志 | zap | 高性能结构化日志 |

---

## 3. 核心流程设计

### 3.1 邮箱注册流程

```
┌──────┐     ┌─────────┐     ┌──────────┐     ┌────────┐     ┌──────┐
│ 用户 │────→│ Handler │────→│  Service │────→│  Repo  │────→│  DB  │
└──────┘     └─────────┘     └──────────┘     └────────┘     └──────┘
                   │               │
                   │               ├── 1. 校验邮箱格式
                   │               ├── 2. 查询邮箱是否已注册
                   │               ├── 3. bcrypt 加密密码
                   │               ├── 4. 创建用户 (status=unverified)
                   │               ├── 5. 生成 6 位验证码
                   │               ├── 6. 存储验证码 (Redis + DB)
                   │               └── 7. 异步发送验证邮件
                   │
              ┌────┴────┐
              │  响应   │
              │  user_id│
              │  status │
              └─────────┘
```

### 3.2 验证码防刷策略

```
发送验证码前检查：
├── 全局频率限制：同一 IP 每小时最多 10 次（Redis INCR + EXPIRE）
├── 目标频率限制：同一邮箱/手机号 60 秒内只能发 1 次
├── 日发送上限：同一邮箱/手机号每天最多 5 次
└── 验证码生成：crypto/rand 生成 6 位数字，存 Redis（TTL=300s）
```

### 3.3 手机号注册/登录流程

```
用户输入手机号 → 获取验证码 → 输入验证码
                                    │
                              ┌─────┴─────┐
                              │ 查询用户  │
                              └─────┬─────┘
                                    │
                        ┌───────────┼───────────┐
                        │                       │
                   用户已存在                用户不存在
                        │                       │
                   验证码校验              创建新用户
                        │                       │
                   登录返回 JWT            登录返回 JWT
```

---

## 4. 接口契约与实现骨架

> 对外 HTTP 接口唯一真相：`docs/api-specs/user-registration.yaml`。  
> 本章保留 Go 代码骨架和实现落点，不再承载字段级最终契约。

### 4.1 类型定义

```go
// internal/domain/user/types/entity.go
package types

import "time"

type User struct {
    ID           int64      `json:"id" gorm:"primaryKey"`
    Username     string     `json:"username" gorm:"size:64;uniqueIndex"`
    Email        *string    `json:"email" gorm:"size:255;uniqueIndex"`
    Phone        *string    `json:"phone" gorm:"size:20;uniqueIndex"`
    PasswordHash string     `json:"-" gorm:"size:255;not null"`
    Status       int8       `json:"status" gorm:"default:0;index"`
    AvatarURL    *string    `json:"avatar_url" gorm:"size:512"`
    CreatedAt    time.Time  `json:"created_at"`
    UpdatedAt    time.Time  `json:"updated_at"`
    DeletedAt    *time.Time `json:"deleted_at" gorm:"index"`
}

type VerificationCode struct {
    ID        int64     `json:"id" gorm:"primaryKey"`
    Target    string    `json:"target" gorm:"size:255;not null;index:idx_target_type"`
    Code      string    `json:"code" gorm:"size:6;not null"`
    Type      int8      `json:"type" gorm:"not null;index:idx_target_type"`
    Used      bool      `json:"used" gorm:"default:false"`
    ExpiresAt time.Time `json:"expires_at" gorm:"index"`
    CreatedAt time.Time `json:"created_at"`
}

const (
    UserStatusUnverified = 0
    UserStatusActive     = 1
    UserStatusDisabled   = 2
    
    CodeTypeRegister    = 1
    CodeTypeLogin       = 2
    CodeTypeResetPasswd = 3
)
```

```go
// internal/domain/user/types/dto.go
package types

type RegisterEmailRequest struct {
    Email            string `json:"email" binding:"required,email,max=255"`
    Password         string `json:"password" binding:"required,min=8,max=128"`
    ConfirmPassword  string `json:"confirm_password" binding:"required,eqfield=Password"`
    AgreementAccepted bool  `json:"agreement_accepted" binding:"required,eq=true"`
}

type SendCodeRequest struct {
    Target string `json:"target" binding:"required"`
    Type   int8   `json:"type" binding:"required,oneof=1 2 3"`
}

type PhoneAuthRequest struct {
    Phone string `json:"phone" binding:"required,len=11"`
    Code  string `json:"code" binding:"required,len=6"`
}

type VerifyEmailRequest struct {
    Email string `json:"email" binding:"required,email"`
    Code  string `json:"code" binding:"required,len=6"`
}

type AuthResponse struct {
    AccessToken  string      `json:"access_token"`
    RefreshToken string      `json:"refresh_token"`
    ExpiresIn    int64       `json:"expires_in"`
    User         UserDTO     `json:"user"`
}

type UserDTO struct {
    ID       int64   `json:"id"`
    Username string  `json:"username"`
    Email    *string `json:"email"`
    Phone    *string `json:"phone"`
    Avatar   *string `json:"avatar_url"`
}
```

### 4.2 Service 层接口

```go
// internal/domain/user/service/auth_service.go
package service

import (
    "context"
    "your-project/internal/domain/user/types"
)

type AuthService interface {
    // RegisterByEmail 邮箱注册
    RegisterByEmail(ctx context.Context, req *types.RegisterEmailRequest) (*types.User, error)
    
    // SendCode 发送验证码
    SendCode(ctx context.Context, req *types.SendCodeRequest) (int, error)
    
    // VerifyEmail 验证邮箱
    VerifyEmail(ctx context.Context, email, code string) error
    
    // PhoneAuth 手机号注册/登录
    PhoneAuth(ctx context.Context, req *types.PhoneAuthRequest) (*types.AuthResponse, error)
}
```

---

## 5. 数据库迁移

```go
// internal/domain/user/types/migration.go
func AutoMigrate(db *gorm.DB) error {
    return db.AutoMigrate(
        &User{},
        &VerificationCode{},
    )
}
```

---

## 6. 配置项

```yaml
# config/user.yaml
user:
  register:
    password_min_length: 8
    password_max_length: 128
    bcrypt_cost: 12
  verification:
    code_length: 6
    code_ttl_seconds: 300        # 5 分钟
    send_interval_seconds: 60    # 60 秒间隔
    daily_limit_per_target: 5    # 每目标每天 5 次
    max_failed_attempts: 3       # 最大错误次数
    ip_hourly_limit: 10          # 同 IP 每小时限制
  jwt:
    access_token_ttl: 7200       # 2 小时
    refresh_token_ttl: 604800    # 7 天
    secret: "${JWT_SECRET}"
```

---

## 7. 测试策略

| 测试类型 | 覆盖范围 | 工具 |
|---------|---------|------|
| 单元测试 | Service 层所有方法 | testify + mockery |
| 集成测试 | Handler → Service → Repository 全链路 | httptest + testcontainers |
| 契约测试 | API 请求/响应格式 | 综合在集成测试中 |
| 压力测试 | 注册接口 QPS 上限 | vegeta |
| 安全测试 | 频率限制、验证码暴力破解 | 手动 + 自动化 |

---

## 8. ADR（架构决策记录）

### ADR-001: 密码存储使用 bcrypt
- **背景**：需要安全存储用户密码
- **决策**：使用 bcrypt 算法，cost=12
- **理由**：行业标准、内置 salt、抗 GPU 暴力破解、Go 标准库原生支持
- **替代方案**：argon2id（更安全但性能更差）、scrypt

### ADR-002: 验证码双写 Redis + DB
- **背景**：验证码需要高频读写 + 持久化
- **决策**：Redis 做频率限制和热数据存储，DB 做持久化和审计
- **理由**：Redis 保证频率限制性能，DB 保证数据不丢失
- **替代方案**：纯 Redis（重启丢失）、纯 DB（频率限制性能差）

### ADR-003: 手机号注册合并登录
- **背景**：手机号场景下注册和登录流程高度相似
- **决策**：同一个接口处理注册和登录
- **理由**：减少用户操作步骤、符合国内主流 App 体验、降低前后端复杂度
