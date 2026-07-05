#!/bin/bash
#
# contract-sync.sh — Python FastAPI 路由 ↔ OpenAPI 契约一致性检查（python-fastapi-vue profile）
#
# 编排层：调用 extract-routes.sh（探测层）+ lib/contract-diff.sh（比对层）
#
# 用法: contract-sync.sh <project-dir> [openapi-path] [report-path]
# 退出码: 0=通过, 非0=存在漂移
#
set -euo pipefail

PROJECT_DIR="${1:-.}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
OPENAPI_PATH="${2:-docs/api/openapi.yaml}"
REPORT_PATH="${3:-.harness/reports/contract-sync-report.md}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_DIR="$(dirname "$SCRIPT_DIR")"
STACKS_DIR="$(dirname "$PROFILE_DIR")"
LIB_DIR="$STACKS_DIR/lib"

mkdir -p "$(dirname "$PROJECT_DIR/$REPORT_PATH")"

{
  echo "# Contract Sync Report — Python 路由 ↔ OpenAPI"
  echo ""
  echo "> 检查时间: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo ""
} > "$PROJECT_DIR/$REPORT_PATH"

# 1. 探测层：提取后端路由
ROUTES_FILE=$(mktemp)
bash "$SCRIPT_DIR/extract-routes.sh" "$PROJECT_DIR" > "$ROUTES_FILE" || true

backend_count=$(wc -l < "$ROUTES_FILE" | tr -d ' ')
echo "## 后端注册路由（${backend_count} 条）" >> "$PROJECT_DIR/$REPORT_PATH"
echo '```' >> "$PROJECT_DIR/$REPORT_PATH"
cat "$ROUTES_FILE" >> "$PROJECT_DIR/$REPORT_PATH"
echo '```' >> "$PROJECT_DIR/$REPORT_PATH"
echo "" >> "$PROJECT_DIR/$REPORT_PATH"

# 2. 协议层：提取 OpenAPI paths
if [[ ! -f "$PROJECT_DIR/$OPENAPI_PATH" ]]; then
  echo "❌ OpenAPI 文件不存在: $OPENAPI_PATH" >> "$PROJECT_DIR/$REPORT_PATH"
  echo "" >> "$PROJECT_DIR/$REPORT_PATH"
  echo "## 结论: ❌ 缺少 OpenAPI 契约文件" >> "$PROJECT_DIR/$REPORT_PATH"
  rm -f "$ROUTES_FILE"
  exit 1
fi

OPENAPI_FILE=$(mktemp)
grep -E '^\s+(/[^:]+):' "$PROJECT_DIR/$OPENAPI_PATH" 2>/dev/null \
  | sed -E 's/^\s+//; s/://' \
  | sort -u > "$OPENAPI_FILE" || true

openapi_count=$(wc -l < "$OPENAPI_FILE" | tr -d ' ')
echo "## OpenAPI paths（${openapi_count} 条）" >> "$PROJECT_DIR/$REPORT_PATH"
echo '```' >> "$PROJECT_DIR/$REPORT_PATH"
cat "$OPENAPI_FILE" >> "$PROJECT_DIR/$REPORT_PATH"
echo '```' >> "$PROJECT_DIR/$REPORT_PATH"
echo "" >> "$PROJECT_DIR/$REPORT_PATH"

# 3. 比对层：调用栈无关的 contract-diff.sh
bash "$LIB_DIR/contract-diff.sh" \
  "$ROUTES_FILE" "$OPENAPI_FILE" \
  "后端路由" "OpenAPI" \
  "$PROJECT_DIR/$REPORT_PATH"

result=$?
rm -f "$ROUTES_FILE" "$OPENAPI_FILE"
exit $result
