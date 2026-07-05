# 用户注册模块 - 需求文档

> 模块：user-registration
> 版本：1.0.0
> 作者：Lead Agent
> 创建时间：2026-03-24
> 最终接口契约：docs/api-specs/user-registration.yaml
> 状态：已确认

---

## 1. 背景与目标

### 1.1 背景
系统需要支持用户通过邮箱和手机号两种方式注册账号，注册后可通过邮箱验证码或短信验证码登录。这是整个系统的基础认证模块。

### 1.2 目标
- 支持邮箱注册 + 邮箱验证码登录
- 支持手机号注册 + 短信验证码登录
- 账号安全防护（频率限制、密码强度校验）
- 注册流程符合国内合规要求（实名制提示）

---

## 2. 功能范围

### 2.1 邮箱注册

| 步骤 | 描述 | 验收标准 |
|------|------|----------|
| 1 | 用户输入邮箱、密码、确认密码 | 邮箱格式校验、密码 >= 8 位含大小写数字 |
| 2 | 前端校验通过，发送注册请求 | 接口响应 < 500ms |
| 3 | 后端创建用户（状态=未验证） | 密码 bcrypt 加密存储 |
| 4 | 发送验证邮件（6 位验证码） | 验证码 5 分钟有效 |
| 5 | 用户输入验证码 | 验证码正确则激活账号 |
| 6 | 跳转到登录页 | 显示"注册成功，请登录"提示 |

### 2.2 手机号注册

| 步骤 | 描述 | 验收标准 |
|------|------|----------|
| 1 | 用户输入手机号、验证码 | 手机号 11 位中国大陆号码格式 |
| 2 | 点击"获取验证码" | 同一号码 60 秒内不重复发送 |
| 3 | 输入短信验证码 | 验证码 5 分钟有效，错误 >= 3 次失效 |
| 4 | 后端创建/查找用户 | 同一手机号重复注册返回已存在提示 |
| 5 | 自动登录，跳转首页 | 返回 JWT Token |

### 2.3 非功能需求

| 维度 | 要求 |
|------|------|
| 性能 | 注册接口响应时间 P99 < 500ms |
| 安全 | 密码 bcrypt cost=12，验证码 6 位数字 |
| 可用性 | 99.9% 可用性，短信服务商故障时优雅降级 |
| 合规 | 用户注册时展示《用户协议》《隐私政策》复选框 |

---

## 3. 数据模型

### 3.1 User 表

```sql
CREATE TABLE users (
    id            BIGINT PRIMARY KEY AUTO_INCREMENT,
    username      VARCHAR(64)  NOT NULL UNIQUE,
    email         VARCHAR(255) UNIQUE,
    phone         VARCHAR(20)  UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    status        TINYINT      NOT NULL DEFAULT 0 COMMENT '0=未验证 1=已激活 2=已禁用',
    avatar_url    VARCHAR(512),
    created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at    TIMESTAMP    NULL,

    INDEX idx_email (email),
    INDEX idx_phone (phone),
    INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 3.2 VerificationCode 表

```sql
CREATE TABLE verification_codes (
    id          BIGINT PRIMARY KEY AUTO_INCREMENT,
    target      VARCHAR(255) NOT NULL COMMENT '邮箱或手机号',
    code        CHAR(6)      NOT NULL,
    type        TINYINT      NOT NULL COMMENT '1=注册 2=登录 3=重置密码',
    used        BOOLEAN      NOT NULL DEFAULT FALSE,
    expires_at  TIMESTAMP    NOT NULL,
    created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_target_type (target, type),
    INDEX idx_expires (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

---

## 4. API 契约（草案摘要）

> 本节仅保留接口范围与关键字段摘要。最终字段、状态码和错误码映射以 `docs/api-specs/user-registration.yaml` 为准。

### 4.1 发送验证码

```
POST /api/v1/auth/send-code
Content-Type: application/json

Request:
{
    "target": "user@example.com",
    "type": 1
}

Response (200):
{
    "code": 0,
    "message": "验证码已发送",
    "data": {
        "expires_in": 300
    }
}
```

### 4.2 邮箱注册

```
POST /api/v1/auth/register/email
Content-Type: application/json

Request:
{
    "email": "user@example.com",
    "password": "SecurePass123",
    "confirm_password": "SecurePass123",
    "agreement_accepted": true
}

Response (200):
{
    "code": 0,
    "message": "注册成功，请查收验证邮件",
    "data": {
        "user_id": 10001,
        "email": "user@example.com",
        "status": "unverified"
    }
}
```

### 4.3 手机号注册/登录

```
POST /api/v1/auth/register/phone
Content-Type: application/json

Request:
{
    "phone": "13800138000",
    "code": "123456"
}

Response (200):
{
    "code": 0,
    "message": "登录成功",
    "data": {
        "access_token": "eyJhbGciOiJIUzI1NiIs...",
        "refresh_token": "eyJhbGciOiJIUzI1NiIs...",
        "expires_in": 7200,
        "user": {
            "id": 10001,
            "username": "user_13800138000",
            "phone": "138****8000",
            "avatar_url": null
        }
    }
}
```

### 4.4 验证邮箱

```
POST /api/v1/auth/verify-email
Content-Type: application/json

Request:
{
    "email": "user@example.com",
    "code": "654321"
}

Response (200):
{
    "code": 0,
    "message": "邮箱验证成功"
}
```

---

## 5. 错误码定义

| 错误码 | HTTP 状态码 | 描述 |
|--------|-------------|------|
| 0 | 200 | 成功 |
| 40001 | 400 | 请求参数错误 |
| 40101 | 401 | 未授权 / Token 过期 |
| 40901 | 409 | 邮箱已注册 |
| 40902 | 409 | 手机号已注册 |
| 42201 | 422 | 密码强度不足 |
| 42901 | 429 | 验证码发送频繁 |
| 42902 | 429 | 验证码错误次数过多 |
| 50001 | 500 | 服务器内部错误 |

---

## 6. 验收标准

- [ ] 邮箱注册完整流程通过
- [ ] 手机号注册+自动登录流程通过
- [ ] 密码强度校验（>=8位、大小写、数字）
- [ ] 验证码 60 秒发送间隔限制
- [ ] 验证码 5 分钟过期
- [ ] 验证码错误 >=3 次失效
- [ ] 重复注册友好提示
- [ ] 用户协议复选框必选
- [ ] 注册页面响应式适配（移动端 + 桌面端）
- [ ] API 错误码覆盖所有异常路径
