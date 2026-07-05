# Next.js 前端编码规范

> 适用范围：使用 **Next.js（App Router）** 的项目
> 若项目使用 Vite + React，请参考 [`frontend-conventions.md`](./frontend-conventions.md)

---

## 1. 目录结构

```
src/
├── app/                    # Next.js App Router 页面
│   ├── layout.tsx          # 根布局（Provider、全局样式）
│   ├── page.tsx            # 首页
│   ├── (auth)/             # 路由分组：认证相关
│   │   ├── login/page.tsx
│   │   └── register/page.tsx
│   ├── (dashboard)/        # 路由分组：需认证页面
│   │   ├── layout.tsx      # 认证守卫
│   │   ├── dashboard/page.tsx
│   │   └── settings/page.tsx
│   └── api/                # Route Handlers (BFF)
│       └── auth/[...nextauth]/route.ts
├── components/             # 组件
│   ├── ui/                 # 基础 UI（Button, Input, Modal...）
│   ├── forms/              # 表单组件（LoginForm, RegisterForm...）
│   └── layouts/            # 布局组件（Header, Sidebar, Footer）
├── lib/                    # 工具库
│   ├── api.ts              # API Client
│   ├── auth.ts             # 认证工具
│   └── utils.ts            # 通用工具
├── hooks/                  # 自定义 Hooks
│   ├── useAuth.ts
│   └── useApi.ts
├── types/                  # TypeScript 类型
│   ├── api.ts              # API 请求/响应类型
│   └── user.ts             # 业务类型
├── styles/                 # 全局样式
│   └── globals.css         # Tailwind 指令 + 全局样式
└── __tests__/              # 测试
    ├── components/
    └── lib/
```

---

## 2. 组件规范

### 2.1 组件文件组织

```tsx
// ✅ 单文件组件（简单组件）
// components/ui/Button.tsx
import { forwardRef } from 'react'

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'ghost'
  size?: 'sm' | 'md' | 'lg'
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  ({ variant = 'primary', size = 'md', className, children, ...props }, ref) => {
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
      <button
        ref={ref}
        className={`${baseStyles} ${variants[variant]} ${sizes[size]} ${className}`}
        {...props}
      >
        {children}
      </button>
    )
  }
)
Button.displayName = 'Button'
```

```tsx
// ✅ 复杂组件：目录组织
// components/forms/RegisterForm/
//   ├── index.tsx           # 主组件
//   ├── EmailStep.tsx       # 邮箱注册步骤
//   ├── PhoneStep.tsx       # 手机号注册步骤
//   ├── useRegisterForm.ts  # 自定义 Hook（表单逻辑）
//   └── RegisterForm.test.tsx
```

### 2.2 Server vs Client Components

```tsx
// ✅ 默认使用 Server Component（零 JS 发送到客户端）
// app/dashboard/page.tsx
import { getUser } from '@/lib/auth'

export default async function DashboardPage() {
  const user = await getUser()
  return <h1>Welcome, {user.name}</h1>
}

// ✅ 需要交互时才用 Client Component
'use client'
// components/forms/RegisterForm.tsx
import { useState } from 'react'

export function RegisterForm() {
  const [email, setEmail] = useState('')
  // ...
}
```

### 2.3 命名规范

```
✅ PascalCase for components:    Button, RegisterForm, UserAvatar
✅ camelCase for hooks:          useAuth, useApi, useDebounce
✅ camelCase for utils:          formatDate, validateEmail
✅ kebab-case for files:         register-form.tsx, use-auth.ts
✅ PascalCase for types:         User, RegisterRequest, ApiResponse
✅ UPPER_SNAKE for constants:    API_BASE_URL, MAX_RETRY_COUNT
```

---

## 3. 状态管理

### 3.1 Server State（数据获取）

```tsx
// ✅ 使用 TanStack Query 管理服务端状态
'use client'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'

export function useUser() {
  return useQuery({
    queryKey: ['user'],
    queryFn: () => api.get('/api/v1/auth/me'),
    staleTime: 5 * 60 * 1000,    // 5 分钟内不重新请求
  })
}

export function useRegisterEmail() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (data: RegisterEmailRequest) => 
      api.post('/api/v1/auth/register/email', data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['user'] })
    },
  })
}
```

### 3.2 Client State（UI 状态）

```tsx
// ✅ 简单 UI 状态用 useState/useReducer
const [isOpen, setIsOpen] = useState(false)

// ✅ 跨组件共享用 Zustand（少量）
// stores/ui-store.ts
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
  baseURL: process.env.NEXT_PUBLIC_API_BASE_URL || '/api',
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
      // Token 过期，跳转登录
      window.location.href = '/login'
    }
    return Promise.reject(error.response?.data)
  }
)
```

---

## 5. 样式规范

### 5.1 Tailwind CSS 优先

```tsx
// ✅ 优先使用 Tailwind 类名
<div className="flex items-center justify-between px-4 py-2 bg-white rounded-lg shadow-sm">
  <span className="text-sm font-medium text-gray-700">Title</span>
  <Button variant="primary" size="sm">Action</Button>
</div>

// ❌ 避免内联 style
<div style={{ display: 'flex', padding: '16px' }}>

// ✅ 复杂动画用 CSS Module
// styles/animation.module.css
@keyframes pulse-glow {
  0%, 100% { box-shadow: 0 0 5px rgba(0, 240, 255, 0.3); }
  50% { box-shadow: 0 0 20px rgba(0, 240, 255, 0.6); }
}
```

### 5.2 响应式设计

```tsx
// ✅ 移动优先
<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
  {/* cards */}
</div>

// ✅ 使用 Tailwind 断点
// sm: 640px, md: 768px, lg: 1024px, xl: 1280px
```

---

## 6. Testing 规范

```tsx
// ✅ 组件测试使用 Testing Library
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { RegisterForm } from './RegisterForm'

describe('RegisterForm', () => {
  it('should show validation error for invalid email', async () => {
    render(<RegisterForm />)
    
    const emailInput = screen.getByLabelText('邮箱')
    const submitButton = screen.getByRole('button', { name: '注册' })
    
    fireEvent.change(emailInput, { target: { value: 'invalid-email' } })
    fireEvent.click(submitButton)
    
    await waitFor(() => {
      expect(screen.getByText('请输入有效的邮箱地址')).toBeInTheDocument()
    })
  })
})
```
