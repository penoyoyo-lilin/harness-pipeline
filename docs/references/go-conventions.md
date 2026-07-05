# Go 编码规范

> 适用范围：所有 `internal/` 下的 Go 代码
> **HTTP 框架无关**：Handler 示例使用标准 `http.HandlerFunc`，具体路由注册按项目 `docs/design-docs/architecture.md` 中的选型适配

---

## 0. 框架适配说明

本文档的 Handler 示例使用标准库 `net/http` 签名，确保与任何 HTTP 框架兼容。各框架的路由注册适配方式：

```go
// --- Chi 路由注册 ---
r.Post("/api/v1/auth/register", handler.Register)

// --- Gin 路由注册（如项目选用）---
// r.POST("/api/v1/auth/register", ginHandlerWrapper(handler.Register))

// --- Echo 路由注册（如项目选用）---
// e.POST("/api/v1/auth/register", echoHandlerWrapper(handler.Register))
```

Handler 实现统一使用 `http.ResponseWriter` + `*http.Request`，通过框架中间件注入的 context 传递请求级数据（如用户身份）。

---

## 1. 命名规范

### 1.1 包命名

```go
✅ 好的命名
package user          // 短小、全小写、单个词
package repository    // 描述性、不缩写

❌ 不好的命名
package userService   // 不要用驼峰
package commonUtil    // 不要加 Util 后缀
package pkg           // 过于模糊
```

### 1.2 变量命名

```go
✅ 好的命名
userID       := 10001        // 驼峰式，缩略词保持大写
httpClient   := &http.Client{}
maxRetry     := 3
isActive     := true

❌ 不好的命名
uid          := 10001        // 不要过度缩写
cnt          := 0            // 写全称 count
flag         := true         // 过于模糊
```

### 1.3 接口命名

```go
// 单方法接口：方法名 + er
type UserRepository interface { ... }
type CodeSender interface { ... }
type AuthService interface { ... }

// 接口实现：接口名 + 具体实现
type gormUserRepo struct { ... }      // GORM 实现
type mockUserRepo struct { ... }      // Mock 实现
type smtpCodeSender struct { ... }    // SMTP 实现
```

---

## 2. 分层规则

### 2.1 每层职责（严格遵守）

```go
// types/ - 只定义数据结构，零外部依赖
package types
type User struct { ... }           // ✅ 纯结构体
var ErrUserNotFound = errors.New(...) // ✅ 错误定义

// repository/ - 只做数据存取，不包含业务逻辑
type UserRepository interface {
    Create(ctx context.Context, user *types.User) error
    FindByEmail(ctx context.Context, email string) (*types.User, error)
}

// service/ - 业务逻辑的核心，不感知 HTTP
type AuthService interface {
    RegisterByEmail(ctx context.Context, req *types.RegisterEmailRequest) (*types.User, error)
}

// handler/ - HTTP 传输层，只做请求解析和响应格式化（框架无关）
func (h *AuthHandler) Register(w http.ResponseWriter, r *http.Request) {
    var req types.RegisterEmailRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        response.ErrorJSON(w, http.StatusBadRequest, 40001, err.Error())
        return
    }
    // 调用 service...
}
```

### 2.2 禁止事项

```go
// ❌ repository 层禁止包含业务逻辑
func (r *gormUserRepo) CreateIfNotExists(...) { ... }

// ❌ service 层禁止使用 HTTP 请求/响应类型
func (s *authService) Register(w http.ResponseWriter, r *http.Request) { ... }

// ❌ handler 层禁止直接操作数据库
func (h *AuthHandler) Register(w http.ResponseWriter, r *http.Request) {
    db.Where("email = ?", email).First(&user)
}
```

---

## 3. 错误处理

### 3.1 业务错误定义

```go
// internal/domain/user/types/errors.go
package types

import "errors"

var (
    ErrUserNotFound      = errors.New("user not found")
    ErrEmailExists       = errors.New("email already registered")
    ErrPhoneExists       = errors.New("phone already registered")
    ErrInvalidCode       = errors.New("invalid verification code")
    ErrCodeExpired       = errors.New("verification code expired")
    ErrTooManyAttempts   = errors.New("too many failed attempts")
    ErrPasswordTooWeak   = errors.New("password does not meet strength requirements")
)
```

### 3.2 错误码映射

```go
// handler 层统一映射
func mapError(err error) (int, int) {
    switch {
    case errors.Is(err, types.ErrEmailExists):
        return http.StatusConflict, 40901
    case errors.Is(err, types.ErrPhoneExists):
        return http.StatusConflict, 40902
    case errors.Is(err, types.ErrInvalidCode):
        return http.StatusBadRequest, 40002
    case errors.Is(err, types.ErrCodeExpired):
        return http.StatusBadRequest, 40003
    case errors.Is(err, types.ErrTooManyAttempts):
        return http.StatusTooManyRequests, 42902
    default:
        return http.StatusInternalServerError, 50001
    }
}
```

---

## 4. 数据库规范

### 4.1 GORM 使用

```go
// ✅ 使用 context
user, err := r.db.WithContext(ctx).Where("email = ?", email).First(&user).Error

// ✅ 批量插入使用 CreateInBatches
r.db.CreateInBatches(&users, 100)

// ❌ 禁止使用 raw SQL（除非性能优化且有注释说明）
r.db.Raw("SELECT * FROM users WHERE email = ?", email)
```

### 4.2 迁移策略

- 使用 GORM AutoMigrate 做开发环境迁移
- 生产环境使用 migration 工具（如 golang-migrate）
- 每个 migration 文件必须包含 UP 和 DOWN

---

## 5. 项目布局参考

```
cmd/
├── server/main.go          # 应用入口
internal/
├── domain/
│   ├── user/               # 用户模块
│   ├── auth/               # 认证模块
│   └── order/              # 订单模块
├── middleware/              # 全局中间件
│   ├── auth.go
│   ├── cors.go
│   ├── logging.go
│   └── recovery.go
├── config/                  # 全局配置加载
│   └── config.go
└── pkg/                     # 内部共享工具
    ├── response/            # 统一响应
    ├── logger/              # 日志封装
    └── validator/           # 参数校验扩展
config/
├── config.yaml              # 主配置文件
└── config.dev.yaml          # 开发环境覆盖
```

---

## 6. Testing 规范

```go
// 表驱动测试
func TestAuthService_RegisterByEmail(t *testing.T) {
    tests := []struct {
        name    string
        req     *types.RegisterEmailRequest
        wantErr error
    }{
        {
            name: "valid registration",
            req:  &types.RegisterEmailRequest{Email: "test@example.com", Password: "SecurePass123"},
            wantErr: nil,
        },
        {
            name: "duplicate email",
            req:  &types.RegisterEmailRequest{Email: "exists@example.com", Password: "SecurePass123"},
            wantErr: types.ErrEmailExists,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // ...
        })
    }
}
```
