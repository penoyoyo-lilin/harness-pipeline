# [模块名称] - 技术架构设计

> 模块：[module-name]  
> 版本：0.1.0  
> 作者：[Agent Name]  
> 依赖：docs/requirements/[module-name].md  
> 接口契约：docs/api-specs/[module-name].yaml  
> 状态：草稿

---

## 1. 架构概述

[描述模块的整体架构设计，包含分层图]

### 目录结构

```
internal/domain/[module]/
├── types/          # 类型定义
├── config/         # 模块配置
├── repository/     # 数据访问层
├── service/        # 业务逻辑层
├── handler/        # HTTP 传输层
└── router/         # 路由注册
```

---

## 2. 技术选型

| 组件 | 选型 | 理由 |
|------|------|------|
| [组件] | [技术] | [理由] |

---

## 3. 核心流程设计

### [流程名称]

```
[流程图或步骤描述]
```

---

## 4. 接口契约（OpenAPI 主源）

**唯一真相文件：** `docs/api-specs/[module-name].yaml`

### 4.1 契约要求

- 使用 OpenAPI 3.0.x YAML
- 每个接口必须写全 `operationId`、请求体、成功响应、错误响应、错误码映射
- 响应结构统一为 `{ code: 0, message: "success", data: {} }`
- 前端类型和 API client 默认从该文件生成
- 编码阶段若修改接口，必须同步更新该文件并触发重新审批

### 4.2 接口摘要

| operationId | METHOD | Path | 描述 |
|-------------|--------|------|------|
| [operationId] | [GET/POST/PUT/DELETE] | [/api/v1/path] | [接口说明] |

---

## 5. 接口实现骨架（Go 代码骨架）

### 5.1 类型定义

```go
// internal/domain/[module]/types/entity.go
package types

type [Entity] struct {
    // 字段定义
}
```

### 5.2 Service 层接口

```go
type [Module]Service interface {
    // 方法签名
}
```

---

## 6. 数据库迁移

```go
func AutoMigrate(db *gorm.DB) error {
    return db.AutoMigrate(
        // 实体列表
    )
}
```

---

## 7. 配置项

```yaml
[module]:
  [key]: [value]
```

---

## 8. 测试策略

| 测试类型 | 覆盖范围 | 工具 |
|---------|---------|------|
| 单元测试 | [范围] | testify |
| 集成测试 | [范围] | httptest |
| 契约测试 | OpenAPI 与 Handler / 前端调用一致性 | schema validation |

---

## 9. Implementation Phases（强制）

将本模块的所有功能点按优先级分层。此表是编码阶段的验收基准，`/review` 会逐项核对 Phase 1 是否完整实现。

| Phase | 优先级 | 功能清单 | 验收标准 | 依赖 |
|-------|--------|---------|---------|------|
| 1 | P0 | [本次编码必须实现的功能，逐项列出] | [每个 P0 功能的可测试验收条件] | 无 |
| 2 | P1 | [可延后但需标注的功能] | — | Phase 1 |
| 3 | P2 | [明确 defer 到未来里程碑的功能] + 目标：[如 M10 管理后台] | — | Phase 2 |

**规则**：
- **Phase 1 不得为空**：必须有至少一个 P0 功能。Phase 1 为空时 `/architect` 不通过，流水线阻塞
- **每个 P0 功能必须有验收标准**：验收标准必须是可测试的（如"API 返回 200"而非"功能正常"）
- **Phase 2+ 必须标注 defer 目标**：明确标注"defer 到哪个里程碑/版本"，不可留空

---

## 10. ADR（架构决策记录）

### ADR-[NNN]: [决策标题]
- **背景**：[背景描述]
- **决策**：[做出的决策]
- **理由**：[为什么选择这个方案]
- **替代方案**：[考虑过但未选择的方案]
