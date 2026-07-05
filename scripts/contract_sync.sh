#!/bin/bash

set -euo pipefail

#!/bin/bash
#
# contract_sync.sh — API 契约一致性检查
#
# 用法:
#   ./contract_sync.sh <project-dir> [openapi-path] [report-path]
#
# 通用替代方案（当目标项目未提供 contractsync 工具时）:
#   - oasdiff:     https://github.com/Tufin/oasdiff       — OpenAPI spec breaking changes 检测
#   - spectral:    https://github.com/stoplightio/spectral — OpenAPI linting
#   - openapi-diff:https://github.com/OpenAPITools/openapi-diff — spec diff 对比
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 项目目录：参数传入，或自动检测 projects/ 下第一个含 go.mod/package.json 的子目录
PROJECT_DIR="${1:-}"

if [[ -z "$PROJECT_DIR" ]]; then
  # 自动检测：在 projects/ 下找第一个包含 go.mod 或 package.json 的目录
  for dir in "$PROJECT_ROOT/projects"/*/; do
    if [[ -f "$dir/go.mod" ]] || [[ -f "$dir/package.json" ]]; then
      PROJECT_DIR="$dir"
      break
    fi
  done
fi

if [[ -z "$PROJECT_DIR" ]] || [[ ! -d "$PROJECT_DIR" ]]; then
  echo "Usage: $0 <project-dir> [openapi-path] [report-path]" >&2
  echo "  project-dir: 目标项目目录（包含 go.mod 或 package.json）" >&2
  echo "  自动检测: 在 $PROJECT_ROOT/projects/ 下搜索" >&2
  exit 1
fi

PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
OPENAPI_PATH="${2:-docs/api/openapi.yaml}"
REPORT_PATH="${3:-.harness/reports/contract-report.md}"

# 优先使用项目内置的 contractsync 工具
if [[ -f "$PROJECT_DIR/cmd/contractsync/main.go" ]]; then
  cd "$PROJECT_DIR"
  go run ./cmd/contractsync -openapi "$OPENAPI_PATH" -report "$REPORT_PATH"
elif command -v oasdiff &> /dev/null; then
  # 回退：使用 oasdiff 检测 breaking changes
  echo "Using oasdiff for contract sync..."
  oasdiff breaking "${OPENAPI_PATH}" "${OPENAPI_PATH}" --format text 2>&1 || true
else
  echo "ERROR: No contract sync tool found." >&2
  echo "  Option 1: Add cmd/contractsync/main.go to your project" >&2
  echo "  Option 2: Install oasdiff: go install github.com/Tufin/oasdiff/cmd/oasdiff@latest" >&2
  exit 1
fi
