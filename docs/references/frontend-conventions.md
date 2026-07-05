# 前端编码规范（Vite + React）

> 适用范围：使用 **Vite + React + TypeScript** 的项目
> 若项目使用 Next.js（App Router），请参考 [`nextjs-conventions.md`](./nextjs-conventions.md)

---

## 1. 目录结构

```
web/                           # 或 src/
├── src/
│   ├── app/                   # 入口与路由
│   │   ├── App.tsx            # 根组件
│   │   ├── main.tsx           # 入口文件
│   │   └── routes.tsx         # 路由配置
│   ├── components/            # 组件
│   │   ├── ui/                # 基础 UI（Button, Input, Modal...）
│   │   ├── forms/             # 表单组件
│   │   └── layout/            # 布局组件（Header, Sidebar, Footer）
│   ├── features/              # 业务模块
│   │   ├── auth/              # 认证相关组件和 hooks
│   │   ├── project/           # 项目管理模块
│   │   └── settings/          # 设置模块
│   ├── hooks/                 # 自定义 Hooks
│   ├── lib/                   # 工具库
│   │   ├── api.ts             # API Client
│   │   ├── auth.ts            # 认证工具
│   │   └── utils.ts           # 通用工具
│   ├── types/                 # TypeScript 类型
│   └── styles/                # 全局样式
│       └── globals.css        # Tailwind 指令
├── e2e/                       # E2E 测试（Playwright）
├── index.html                 # HTML 入口
├── vite.config.ts
├── tsconfig.json
├── tailwind.config.ts
└── playwright.config.ts
```

---

## 2. 组件规范

### 2.1 函数组件（默认）

```tsx
// ✅ 所有组件默认为函数组件
// components/ui/Button.tsx
import type { ButtonHTMLAttributes } from 'react'

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'ghost'
  size?: 'sm' | 'md' | 'lg'
}

export function Button({ variant = 'primary', size = 'md', className, children, ...props }: ButtonProps) {
  const baseStyles = 'inline-flex items-center justify-center rounded-lg font-medium transition-colors'
  const variants = {
    primary: 'bg-blue-600 text-white hover:bg-blue-700',
    secondary: 'bg-gray-200 text-gray-900 hover:bg-gray-300',
    ghost: 'text-gray-600 hover:bg-gray-100',
  }
  const sizes = {
    sm: 'px-3 py-1.5 text-sm',
    md: 'px-4 py-2 text-base',
    lg: 'px-6 py-3 text-lg',
  }
  return (
    <button className={`${baseStyles} ${variants[variant]} ${sizes[size]} ${className}`} {...props}>
      {children}
    </button>
  )
}
```

### 2.2 命名规范

```
PascalCase for components:    Button, RegisterForm, UserAvatar
camelCase for hooks:          useAuth, useApi, useDebounce
camelCase for utils:          formatDate, validateEmail
kebab-case for files:         register-form.tsx, use-auth.ts
PascalCase for types:         User, RegisterRequest, ApiResponse
UPPER_SNAKE for constants:    API_BASE_URL, MAX_RETRY_COUNT
```

---

## 3. 状态管理

### 3.1 Server State（数据获取）

```tsx
// ✅ 使用 TanStack Query 管理服务端状态
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'

export function useUser() {
  return useQuery({
    queryKey: ['user'],
    queryFn: () => api.get('/api/v1/auth/me'),
    staleTime: 5 * 60 * 1000,
  })
}
```

### 3.2 Client State（UI 状态）

```tsx
// ✅ 简单 UI 状态用 useState/useReducer
const [isOpen, setIsOpen] = useState(false)

// ✅ 跨组件共享用 Zustand
import { create } from 'zustand'

interface UIStore {
  sidebarOpen: boolean
  toggleSidebar: () => void
}

export const useUIStore = create<UIStore>((set) => ({
  sidebarOpen: true,
  toggleSidebar: () => set((s) => ({ sidebarOpen: !s.sidebarOpen })),
}))
```

---

## 4. API 调用

```tsx
// lib/api.ts
import axios from 'axios'

export const api = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || '/api',
  timeout: 10000,
})

// 请求拦截器：自动附加 Token
api.interceptors.request.use((config) => {
  const token = getToken()
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

// 响应拦截器：统一错误处理
api.interceptors.response.use(
  (response) => response.data,
  (error) => {
    if (error.response?.data?.code === 40101) {
      window.location.href = '/login'
    }
    return Promise.reject(error.response?.data)
  }
)
```

> **注意**：Vite 使用 `import.meta.env.VITE_*` 访问环境变量，而非 Next.js 的 `process.env.NEXT_PUBLIC_*`。

---

## 5. 样式规范

### 5.1 Tailwind CSS 优先

```tsx
// ✅ 优先使用 Tailwind 类名
<div className="flex items-center justify-between px-4 py-2 bg-white rounded-lg shadow-sm">
  <span className="text-sm font-medium text-gray-700">Title</span>
</div>

// ❌ 避免内联 style
<div style={{ display: 'flex', padding: '16px' }}>
```

### 5.2 响应式设计

```tsx
// ✅ 移动优先
<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
```

---

## 6. Testing 规范

```tsx
// ✅ 组件测试使用 Testing Library + Vitest
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { describe, it, expect } from 'vitest'
import { RegisterForm } from './RegisterForm'

describe('RegisterForm', () => {
  it('should show validation error for invalid email', async () => {
    render(<RegisterForm />)
    fireEvent.change(screen.getByLabelText('邮箱'), { target: { value: 'invalid' } })
    fireEvent.click(screen.getByRole('button', { name: '注册' }))
    await waitFor(() => {
      expect(screen.getByText('请输入有效的邮箱地址')).toBeInTheDocument()
    })
  })
})
```

### E2E 测试（Playwright）

```typescript
// e2e/auth.spec.ts
import { test, expect } from '@playwright/test'

test('user can register with email', async ({ page }) => {
  await page.goto('/register')
  await page.fill('[name="email"]', 'test@example.com')
  await page.fill('[name="password"]', 'SecurePass123')
  await page.fill('[name="confirm_password"]', 'SecurePass123')
  await page.click('button[type="submit"]')
  await expect(page).toHaveURL('/login')
})
```
