#!/bin/bash
#
# integration-test.sh — Python FastAPI 后端集成测试（python-fastapi-vue profile）
#
# 用法: integration-test.sh <project-dir>
# 退出码: 0=通过, 非0=失败
#
set -euo pipefail

PROJECT_DIR="${1:-.}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

cd "$PROJECT_DIR"

# 1. 编译验证（语法检查）
if ! python -m py_compile $(find app -name '*.py' 2>/dev/null) 2>&1; then
  echo "FAIL: Python 语法检查失败"
  exit 1
fi

# 2. 运行测试（pytest）
if [[ -f "pytest.ini" ]] || [[ -f "pyproject.toml" ]] || [[ -f "setup.cfg" ]]; then
  echo "运行 pytest..."
  if ! python -m pytest app/ -v 2>&1; then
    echo "FAIL: pytest 测试失败"
    exit 1
  fi
else
  echo "SKIP: 未找到 pytest 配置，跳过测试"
fi

echo "PASS: Python 后端集成测试通过"
exit 0
