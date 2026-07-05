# Modular Vibe Coding

> **Purpose**: 提供模块化编码的工作流程和模板，将大功能拆解为独立、可测试的模块

## 概述

Modular Vibe Coding 是一种将复杂功能分解为小型、独立模块的编码方法论。每个模块：
- 有清晰的单一职责
- 定义明确的接口
- 可独立开发和测试
- 通过组合构建复杂功能

## 核心原则

### 1. 单一职责原则 (SRP)

每个模块只做一件事，做好一件事。

```go
// ❌ 不好的设计：一个模块处理太多职责
type UserModule struct {
    // 用户管理 + 认证 + 授权 + 审计
}

// ✅ 好的设计：拆分为独立模块
type UserModule struct {}      // 用户数据管理
type AuthModule struct {}      // 身份认证
type PermissionModule struct {} // 权限控制
type AuditModule struct {}      // 操作审计
```

### 2. 接口隔离

模块间通过接口通信，不依赖具体实现。

```go
// 定义在使用方（consumer）
type UserRepository interface {
    FindByID(ctx context.Context, id string) (*User, error)
    Save(ctx context.Context, user *User) error
}

// 实现在 repository 包
type userRepository struct {
    db *sql.DB
}
```

### 3. 依赖注入

通过构造函数注入依赖，便于测试和替换。

```go
// ✅ 依赖注入
type UserService struct {
    repo UserRepository
    cache Cache
    logger Logger
}

func NewUserService(repo UserRepository, cache Cache, logger Logger) *UserService {
    return &UserService{repo, cache, logger}
}

// ❌ 全局依赖或内部创建
type UserService struct {}
func (s *UserService) GetUser(id string) {
    db := globalDB  // 不要这样
}
```

## 模块分解流程

### Step 1: 识别领域边界

```
需求: 实现电商订单系统

领域边界识别:
├── Order (订单) - 核心聚合根
├── Product (商品) - 商品信息
├── Inventory (库存) - 库存管理
├── Payment (支付) - 支付处理
├── Shipping (物流) - 配送管理
└── Notification (通知) - 消息通知
```

### Step 2: 定义模块接口

每个模块暴露最小必要接口：

```go
// order/module.go
package order

type Module interface {
    // 命令
    CreateOrder(ctx context.Context, cmd CreateOrderCmd) (*Order, error)
    CancelOrder(ctx context.Context, orderID string) error
    ConfirmOrder(ctx context.Context, orderID string) error
    
    // 查询
    GetOrder(ctx context.Context, orderID string) (*Order, error)
    ListOrders(ctx context.Context, query ListQuery) ([]*Order, error)
}

type CreateOrderCmd struct {
    UserID      string
    Items       []OrderItem
    ShippingAddr Address
}
```

### Step 3: 实现模块内部

按 Domain 分层实现：

```
internal/domain/order/
├── types.go          # 领域模型
├── config.go         # 模块配置
├── repository.go     # 仓储接口
├── repository_pg.go  # 仓储实现
├── service.go        # 业务逻辑
├── handler.go        # HTTP 处理器
└── module.go         # 模块组装
```

### Step 4: 模块组装

```go
// order/module.go
func NewModule(config Config, deps Dependencies) (Module, error) {
    // 1. 创建仓储
    repo := newPostgresRepository(deps.DB)
    
    // 2. 创建服务
    svc := &service{
        repo:    repo,
        product: deps.ProductModule,
        payment: deps.PaymentModule,
        eventBus: deps.EventBus,
    }
    
    // 3. 创建处理器
    handler := &HTTPHandler{service: svc}
    
    // 4. 返回模块
    return &module{
        service: svc,
        handler: handler,
    }, nil
}
```

## 模块模板

### Go 模块模板

```go
// internal/domain/{module}/types.go
package {module}

import "time"

// 领域模型
type Entity struct {
    ID        string
    CreatedAt time.Time
    UpdatedAt time.Time
}

// 值对象
type ValueObject struct {
    // fields
}

// 领域事件
type Event struct {
    Type      string
    EntityID  string
    Payload   map[string]any
    OccurredAt time.Time
}
```

```go
// internal/domain/{module}/repository.go
package {module}

import "context"

type Repository interface {
    FindByID(ctx context.Context, id string) (*Entity, error)
    FindAll(ctx context.Context, query Query) ([]*Entity, error)
    Save(ctx context.Context, entity *Entity) error
    Delete(ctx context.Context, id string) error
}

type Query struct {
    Limit  int
    Offset int
    Filter map[string]any
}
```

```go
// internal/domain/{module}/service.go
package {module}

type Service struct {
    repo Repository
    // 其他依赖
}

func NewService(repo Repository) *Service {
    return &Service{repo: repo}
}

func (s *Service) Create(ctx context.Context, cmd CreateCmd) (*Entity, error) {
    // 业务逻辑
}
```

### React 模块模板

```typescript
// app/{module}/types.ts
export interface Entity {
  id: string;
  createdAt: string;
  updatedAt: string;
}

export interface CreateDto {
  // fields
}
```

```typescript
// app/{module}/api.ts
import { apiClient } from '@/lib/api';
import { Entity, CreateDto } from './types';

export async function getEntity(id: string): Promise<Entity> {
  const res = await apiClient.get(`/api/${module}/${id}`);
  return res.data;
}

export async function createEntity(data: CreateDto): Promise<Entity> {
  const res = await apiClient.post(`/api/${module}`, data);
  return res.data;
}
```

```typescript
// app/{module}/hooks.ts
'use client';

import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { getEntity, createEntity } from './api';

export function useEntity(id: string) {
  return useQuery({
    queryKey: ['{module}', id],
    queryFn: () => getEntity(id),
  });
}

export function useCreateEntity() {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: createEntity,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['{module}'] });
    },
  });
}
```

## 模块间通信

### 同步调用

```go
// 通过接口调用
orderSvc := order.NewModule(config, order.Dependencies{
    ProductModule: productModule,
    PaymentModule: paymentModule,
})
```

### 异步事件

```go
// 发布事件
func (s *OrderService) ConfirmOrder(ctx context.Context, orderID string) error {
    // ... 确认订单逻辑
    
    s.eventBus.Publish(ctx, OrderConfirmedEvent{
        OrderID: orderID,
        UserID:  order.UserID,
        Amount:  order.TotalAmount,
    })
    
    return nil
}

// 订阅事件
func (s *NotificationService) OnOrderConfirmed(ctx context.Context, event OrderConfirmedEvent) {
    s.sendEmail(event.UserID, "订单已确认", ...)
}
```

## 测试策略

### 单元测试

```go
func TestService_Create(t *testing.T) {
    // 使用 mock 仓储
    mockRepo := &mockRepository{}
    svc := NewService(mockRepo)
    
    // 测试业务逻辑
    entity, err := svc.Create(context.Background(), CreateCmd{...})
    
    // 断言
    require.NoError(t, err)
    assert.NotEmpty(t, entity.ID)
}
```

### 集成测试

```go
func TestModule_Integration(t *testing.T) {
    // 使用真实数据库
    db := setupTestDB(t)
    
    module, err := NewModule(testConfig, Dependencies{DB: db})
    require.NoError(t, err)
    
    // 测试完整流程
    entity, err := module.Create(ctx, CreateCmd{...})
    require.NoError(t, err)
    
    found, err := module.Get(ctx, entity.ID)
    require.NoError(t, err)
    assert.Equal(t, entity.ID, found.ID)
}
```

## 使用指南

### 创建新模块

1. **复制模板**
   ```bash
   cp -r templates/module-go internal/domain/{new-module}
   ```

2. **替换占位符**
   - `{module}` → 模块名
   - `{Module}` → 模块名（首字母大写）

3. **定义领域模型**
   - 在 `types.go` 中定义实体、值对象、事件

4. **实现业务逻辑**
   - 在 `service.go` 中实现用例

5. **创建接口层**
   - 在 `handler.go` 中实现 HTTP 接口

6. **编写测试**
   - 表驱动测试覆盖主要场景

### 模块演进

```
初始版本 → 添加功能 → 拆分模块 → 提取通用组件
    ↓         ↓          ↓           ↓
  MVP       迭代       重构        平台化
```

## 最佳实践

1. **保持模块小型** - 一个模块应该能在 1-2 天内完成
2. **先写接口** - 定义好契约再实现
3. **延迟优化** - 先让模块工作，再优化性能
4. **文档即代码** - 接口定义就是最好的文档
5. **版本控制** - 模块接口变更要考虑向后兼容
