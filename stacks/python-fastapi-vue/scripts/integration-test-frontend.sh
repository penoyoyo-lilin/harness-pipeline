#!/bin/bash
#
# integration-test-frontend.sh — Vue 前端集成测试（python-fastapi-vue profile）
#
# 用法: integration-test-frontend.sh <project-dir>
# 退出码: 0=通过, 非0=失败
#
set -euo pipefail

PROJECT_DIR="${1:-.}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

cd "$PROJECT_DIR"

# 检测包管理器
if [[ -f "pnpm-lock.yaml" ]] && command -v pnpm &>/dev/null; then
  PM=pnpm
elif [[ -f "yarn.lock" ]] && command -v yarn &>/dev/null; then
  PM=yarn
else
  PM=npm
fi

# 1. 类型检查 + 构建
if ! $PM run build 2>&1; then
  echo "FAIL: 前端构建失败"
  exit 1
fi

# 2. lint（如脚本存在）
if grep -q '"lint"' package.json 2>/dev/null; then
  if ! $PM run lint 2>&1; then
    echo "FAIL: 前端 lint 失败"
    exit 1
  fi
fi

# 3. 测试（如脚本存在）
if grep -q '"test"' package.json 2>/dev/null; then
  if ! $PM run test 2>&1; then
    echo "FAIL: 前端测试失败"
    exit 1
  fi
fi

echo "PASS: 前端集成测试通过"
exit 0
