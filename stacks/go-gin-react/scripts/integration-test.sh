#!/bin/bash
#
# integration-test.sh — Go 后端集成测试（go-gin-react profile）
#
# 用法: integration-test.sh <project-dir>
# 退出码: 0=通过, 非0=失败
#
# 运行 Handler → Service → Repository 全链路测试，并验证编译。
#
set -euo pipefail

PROJECT_DIR="${1:-.}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

cd "$PROJECT_DIR"

# 1. 编译验证
if ! go build ./... 2>&1; then
  echo "FAIL: go build 失败"
  exit 1
fi

# 2. 运行集成测试（按命名约定 *_integration_test.go 或带 // +build integration 标签）
echo "运行集成测试..."
if ! go test -tags=integration ./internal/... 2>&1; then
  echo "FAIL: 集成测试失败"
  exit 1
fi

# 3. 若无带 integration 标签的测试，回退到全量测试
if ! go test ./internal/... 2>&1; then
  echo "FAIL: 测试失败"
  exit 1
fi

echo "PASS: Go 后端集成测试通过"
exit 0
