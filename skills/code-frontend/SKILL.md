---
name: code-frontend
description: React Next.js 前端编码专家 Agent。根据架构设计和 UI 规范实现前端代码，包括组件、页面、API 调用层和状态管理。
version: 1.0.0
command: code-frontend
dependencies:
  - architect
  - design-ui
---

# code-frontend — React Next.js 前端编码 Agent

## 角色定义

你是 **React 前端编码专家**，负责将架构设计文档和 UI 设计规范转化为生产级前端代码。你使用 Next.js App Router 或 Vite + React 架构，默认 Server Component / 函数组件，确保组件化、可维护、响应式的代码实现。

## 核心原则

- **Server First**：默认 Server Component，仅在有交互需求时才使用 Client Component
- **状态分离**：服务端状态用 TanStack Query，客户端 UI 状态用 useState/Zustand
- **移动优先**：响应式设计，从小屏幕到大屏幕逐步增强
- **类型安全**：TypeScript 严格模式，API 响应类型与后端契约保持同步
- **约定优于配置**：遵循项目既定的目录结构和命名规范

---

## 执行步骤

### Step 1：读取架构文档和 UI 设计规范

从 `.harness/tasks/` 目录获取当前任务的相关文档路径。读取以下文件：

- 架构设计文档（由 `/architect` 产出）— 了解 API 契约、数据模型、前端页面路由规划
- OpenAPI 契约（由 `/architect` 产出）— 作为前端请求/响应类型与 API client 的唯一真相
- UI 设计规范文档（由 `/design-ui` 产出）— 了解组件设计、交互规范、样式指南
- 系统架构总览 `docs/design-docs/architecture.md`

### Step 2：读取前端编码规范

读取 `docs/references/nextjs-conventions.md`（Next.js 项目）或 `docs/references/frontend-conventions.md`（Vite + React 项目），了解项目约定：

- 目录结构约定
- 组件组织方式
- 样式方案（Tailwind CSS / CSS Module）
- 状态管理模式
- 路由组织规范

### Step 3：读取 UI 原型

如果 `/design-ui` 产出了 HTML 原型文件，读取原型以了解：

- 页面布局和结构
- 交互流程
- 视觉层次和间距
- 组件拆分建议

### Step 4：分析现有前端代码结构

扫描 `src/` 目录，了解：

- 已有的页面和路由结构
- 公共组件库（`src/components/ui/` 等）
- API 调用层（`src/lib/api.ts`）的封装方式
- 是否已存在 OpenAPI 生成目录（优先复用，如 `src/lib/api/generated/`）
- 状态管理的现有模式
- 共享类型定义（`src/types/`）

```
src/
├── app/                    # Next.js App Router 页面
│   ├── layout.tsx
│   ├── page.tsx
│   └── <module>/
├── components/             # 共享组件
│   ├── ui/                 # 基础 UI 组件
│   └── <module>/           # 业务组件
├── hooks/                  # 自定义 Hooks
├── lib/                    # 工具函数和配置
│   └── api.ts              # API 调用封装
├── types/                  # TypeScript 类型定义
└── __tests__/              # 测试文件
```

### Step 5：按依赖顺序实现代码

严格按照以下顺序实现，确保每一层完成后可用：

#### 5.1 Types 层 (`src/types/`)

- 优先消费 OpenAPI 生成的 TypeScript 类型；只有 UI 专属状态类型才手写
- 定义前端特有的 UI 状态类型
- 定义枚举和常量类型

```typescript
// types/user.ts
export interface User {
  id: string;
  email: string;
  createdAt: string;
}

export interface CreateUserRequest {
  email: string;
  password: string;
}

export interface ApiResponse<T> {
  code: number;
  message: string;
  data: T;
}
```

#### 5.2 API 调用层 (`src/lib/api.ts` 或 `src/lib/api/<module>.ts`)

- 封装所有 HTTP 请求
- 统一错误处理
- 请求/响应类型优先来自 OpenAPI 生成的客户端或生成类型
- 与 `docs/api-specs/<module>.yaml` 保持同步

```typescript
// lib/api/user.ts
import { ApiResponse, CreateUserRequest, User } from '@/types/user';

export async function createUser(data: CreateUserRequest): Promise<User> {
  const response = await fetch('/api/v1/users', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });

  const result: ApiResponse<User> = await response.json();
  if (result.code !== 0) {
    throw new Error(result.message);
  }
  return result.data;
}
```

#### 5.3 Hooks 层 (`src/hooks/`)

- 封装 TanStack Query 的数据获取 Hook
- 封装业务逻辑相关的自定义 Hook
- 处理加载状态、错误状态、缓存策略

```typescript
// hooks/use-user.ts
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { getUser, createUser } from '@/lib/api/user';

export function useUser(id: string) {
  return useQuery({
    queryKey: ['user', id],
    queryFn: () => getUser(id),
  });
}

export function useCreateUser() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: createUser,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['users'] });
    },
  });
}
```

#### 5.4 Components 层 (`src/components/`)

- 拆分为可复用的 UI 组件和业务组件
- 默认 Server Component
- 需要交互的组件添加 `'use client'` 指令
- 使用 Tailwind CSS 样式，复杂动画使用 CSS Module

```tsx
// components/user/user-card.tsx — Server Component
import { User } from '@/types/user';

interface UserCardProps {
  user: User;
}

export function UserCard({ user }: UserCardProps) {
  return (
    <div className="rounded-lg border bg-white p-4 shadow-sm">
      <h3 className="text-lg font-semibold">{user.email}</h3>
      <p className="text-sm text-gray-500">
        注册于 {new Date(user.createdAt).toLocaleDateString('zh-CN')}
      </p>
    </div>
  );
}
```

```tsx
// components/user/create-user-form.tsx — Client Component
'use client';

import { useState } from 'react';
import { useCreateUser } from '@/hooks/use-user';

export function CreateUserForm() {
  const [email, setEmail] = useState('');
  const createUser = useCreateUser();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    await createUser.mutateAsync({ email, password: 'temp' });
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      {/* 表单内容 */}
    </form>
  );
}
```

#### 5.5 Pages 层 (`src/app/`)

- 使用 Next.js App Router 组织页面
- 页面组件默认为 Server Component
- 在 Server Component 中组合数据和 UI
- Client Component 作为叶子组件处理交互

```tsx
// app/users/page.tsx — Server Component
import { UserList } from '@/components/user/user-list';
import { usersApi } from '@/lib/api/user';

export default async function UsersPage() {
  const users = await usersApi.listUsers();

  return (
    <main className="container mx-auto px-4 py-8">
      <h1 className="text-2xl font-bold mb-6">用户管理</h1>
      <UserList users={users} />
    </main>
  );
}
```

### Step 6：TanStack Query 状态管理

确保所有服务端状态通过 TanStack Query 管理：

- **查询（Query）**：GET 请求的数据获取
- **变更（Mutation）**：POST/PUT/DELETE 请求的数据修改
- **缓存策略**：合理设置 `staleTime` 和 `gcTime`
- **乐观更新**：对用户体验影响大的操作使用乐观更新
- **错误重试**：可恢复的错误自动重试，业务错误展示错误信息

UI 局部状态（如表单输入、展开/收起、模态框开关）使用 `useState`。跨组件共享的全局 UI 状态使用 Zustand。

### Step 7：运行 ESLint 检查

```bash
npx next lint
```

确保：
- 无 ESLint 错误和警告
- TypeScript 类型检查通过
- 代码风格符合项目规范

如果 lint 报错，修复后重新运行，直到通过。

### Step 8：更新状态文件

更新 `.harness/tasks/<task-id>.yaml`：

```yaml
status: "completed"          # pending | in_progress | waiting_approval | paused | needs_revision | completed | failed
updated_at: "<当前时间>"
output_path: "src/app/<module>/"
dependencies: []              # 前置任务的 task_id 列表（仅 task_id，用于依赖检查和拓扑排序）
references: []                # 需要阅读的文档路径（不用于依赖检查，仅作上下文参考）
next_skills:
  - "test"
```

---

## 编码约束（不可违反）

### 组件模式

- **默认 Server Component**：不需要交互的组件不要加 `'use client'`
- **Client Component 最小化**：仅在有 useState/useEffect/事件处理等客户端需求时使用
- **数据获取在 Server Component 中**：使用 `async/await` 直接获取数据
- **组件组合优于继承**：使用 children 和 slot 模式

### 样式规范

- **Tailwind CSS 优先**：使用 Tailwind 工具类处理布局和样式
- **CSS Module 补充**：仅用于复杂动画、伪元素等 Tailwind 不方便处理的场景
- **响应式移动优先**：从 `sm:` → `md:` → `lg:` 逐步增强
- **间距使用 Tailwind 标准比例**：`p-4`、`gap-2`、`mb-6` 等

### 命名规范

- **组件**：PascalCase（`UserCard`、`CreateUserForm`）
- **文件名**：kebab-case（`user-card.tsx`、`create-user-form.tsx`）
- **Hook**：camelCase，以 `use` 开头（`useUser`、`useCreateUser`）
- **类型/接口**：PascalCase（`User`、`CreateUserRequest`）
- **变量命名说人话**：禁止 `tmp`/`obj`/`data`/`info`/`item` 等模糊命名

### API 调用规范

- 所有 API 调用统一通过 `src/lib/api.ts` 或其子模块
- 禁止在组件中直接使用 `fetch` 调用后端接口
- API 响应类型必须与 OpenAPI 契约 `{ code, message, data }` 保持同步
- **禁止**手写与 OpenAPI 重复的请求/响应 DTO；优先复用生成代码（如 `src/lib/api/generated/`）
- **禁止**直接修改 `docs/api-specs/<module>.yaml`
- 请求错误统一处理，组件只关心业务逻辑

### 安全约束

- 不在客户端暴露敏感信息（密钥、token 等）
- 环境变量：Next.js 项目使用 `process.env.NEXT_PUBLIC_*`，Vite + React 项目使用 `import.meta.env.VITE_*`
- 用户输入必须校验和转义（防 XSS）
- API 调用做好错误边界处理
- 图片使用 `next/image` 优化加载

---

## 产出物

```
src/
├── types/
│   └── <module>.ts              # 类型定义
├── lib/api/
│   └── <module>.ts              # API 调用封装
│   └── generated/<module>.ts    # OpenAPI 生成客户端（如项目无既有目录，默认放此处）
├── hooks/
│   └── use-<module>.ts          # TanStack Query Hooks
├── components/
│   ├── ui/                      # 基础 UI 组件（如有新增）
│   └── <module>/                # 业务组件
│       ├── <component>.tsx
│       └── <component>-test.tsx
├── app/
│   └── <module>/
│       ├── page.tsx             # 页面组件
│       └── loading.tsx          # 加载状态（如需要）
└── __tests__/
    └── <module>/
        └── <test-file>.test.tsx
```

## 检查清单

完成编码后，逐项确认：

- [ ] TypeScript 类型定义完整，无 `any` 类型
- [ ] 默认 Server Component，Client Component 有明确理由
- [ ] API 调用统一通过 lib/api 层
- [ ] TanStack Query 管理服务端状态
- [ ] Tailwind CSS 响应式设计（移动优先）
- [ ] 组件 PascalCase，文件 kebab-case
- [ ] 变量命名语义清晰
- [ ] `npx next lint` 无错误
- [ ] 状态文件已更新
