# CI/CD 说明文档

> 版本：1.0.0  
> 更新时间：2026-03-24

---

## 1. GitHub Actions 工作流

### 1.1 PR 合入检查（ci.yml）

每次 PR 触发，必须通过以下检查：

```yaml
name: CI Pipeline
on:
  pull_request:
    branches: [main, develop]
  push:
    branches: [develop]

jobs:
  # Go 后端检查
  go-test:
    runs-on: ubuntu-latest
    services:
      mysql:
        image: mysql:8.0
        env:
          MYSQL_ROOT_PASSWORD: test
          MYSQL_DATABASE: testdb
        ports: ["3306:3306"]
        options: >-
          --health-cmd="mysqladmin ping"
          --health-interval=10s
          --health-timeout=5s
          --health-retries=3
      redis:
        image: redis:7-alpine
        ports: ["6379:6379"]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.22'
      - run: go mod download
      - run: golangci-lint run ./...
      - run: go test -race -coverprofile=coverage.out ./...
      - run: go test -race -coverprofile=coverage.out ./... -covermode=atomic

  # 前端检查
  frontend-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: npm ci
      - run: npx eslint src/ --max-warnings=0
      - run: npm run test:ci
      - run: npm run build
```

### 1.2 生产部署（deploy.yml）

```yaml
name: Deploy to Production
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    needs: [go-test, frontend-test]  # CI 全绿才部署
    steps:
      - uses: actions/checkout@v4
      - name: Build and Push Backend
        run: |
          docker build -t backend:${{ github.sha }} ./cmd/server
          docker push registry/backend:${{ github.sha }}
      - name: Build and Push Frontend
        run: |
          docker build -t frontend:${{ github.sha }} .
          docker push registry/frontend:${{ github.sha }}
```

### 1.3 熵扫描（entropy.yml）

每周一定时执行代码偏差扫描：

```yaml
name: Entropy Scan
on:
  schedule:
    - cron: '0 9 * * 1'  # 每周一 9:00 UTC
  workflow_dispatch: {}

jobs:
  entropy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # 需要完整历史
      - name: Run Entropy Scan
        run: |
          # Codex 执行熵扫描
          codex "/entropy 扫描当前代码库，输出偏差报告"
```

---

## 2. PR 合入规范

### 2.1 必要条件

- [ ] CI 全绿（Go lint + test + ESLint + build）
- [ ] 至少 1 人 Code Review 通过
- [ ] PR 描述包含：变更说明、测试说明
- [ ] 无 `TODO` 遗留（或创建 Issue 跟踪）

### 2.2 PR 模板

```markdown
## 变更说明
> 简要描述本次变更

## 变更类型
- [ ] 新功能
- [ ] Bug 修复
- [ ] 重构
- [ ] 文档更新

## 测试说明
- 单元测试覆盖：xxx
- 手动测试：xxx

## 关联 Issue
Closes #xxx
```

---

## 3. 环境配置

| 环境 | 分支 | 触发 | 自动部署 |
|------|------|------|---------|
| Development | develop | push | ✅ |
| Staging | release/* | PR to main | ✅ |
| Production | main | merge | ✅（需人工确认） |
