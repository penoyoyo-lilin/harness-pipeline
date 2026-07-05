#!/bin/bash
#
# baseline-check.sh — Go Domain 分层依赖方向检查（go-gin-react profile）
#
# 用法: baseline-check.sh <project-dir>
# 退出码: 0=通过, 非0=存在违规
# 报告: 输出到 stdout，同时写入 .harness/reports/baseline-check.md
#
set -euo pipefail

PROJECT_DIR="${1:-.}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
REPORT_DIR="$PROJECT_DIR/.harness/reports"
REPORT_FILE="$REPORT_DIR/baseline-check.md"

mkdir -p "$REPORT_DIR"

DOMAIN_DIR="$PROJECT_DIR/internal/domain"

if [[ ! -d "$DOMAIN_DIR" ]]; then
  echo "SKIP: $DOMAIN_DIR 不存在（首次初始化或无后端代码）"
  exit 0
fi

violations=0
{
  echo "# Baseline Check — Go Domain 分层"
  echo ""
  echo "> 检查时间: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "> 检查范围: \`internal/domain/*/\`"
  echo "> 说明: 排除 *_test.go（测试文件中的 mock 引用属正常模式）"
  echo ""
} > "$REPORT_FILE"

check_violation() {
  local layer="$1"
  local forbidden_pkg="$2"
  local desc="$3"
  local hits
  # 只检测 import 语句（^\s*" 或 	"），排除注释和字符串中的关键词
  # forbidden_pkg 为 import 路径片段，如 internal/domain/spec/repository
  local forbidden_import
  forbidden_import=$(echo "$forbidden_pkg" | sed 's/\//\\\//g')
  hits=$(grep -rnE "^[[:space:]]*\".*${forbidden_import}\"" "$DOMAIN_DIR"/*/"$layer"/ 2>/dev/null \
    --include="*.go" | grep -v '_test\.go' || true)
  if [[ -n "$hits" ]]; then
    echo "FAIL: $desc" | tee -a "$REPORT_FILE"
    echo "$hits" | sed "s|$PROJECT_DIR/||" | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"
    violations=$((violations + 1))
  else
    echo "PASS: $desc" | tee -a "$REPORT_FILE"
  fi
}

# 依赖方向: handler → service → repository → types（严格单向）
# forbidden_pkg 用 import 路径片段，匹配 internal/domain/<module>/<layer>
# 逐模块检查：handler 不应 import 同模块的 repository
for module_dir in "$DOMAIN_DIR"/*/; do
  [[ -d "$module_dir" ]] || continue
  module_name=$(basename "$module_dir")

  # handler 层不应 import 同模块 repository
  check_violation "handler"   "internal/domain/${module_name}/repository" "${module_name}/handler 不应引用 ${module_name}/repository"
  # repository 层不应 import 同模块 service/handler
  check_violation "repository" "internal/domain/${module_name}/service"    "${module_name}/repository 不应引用 ${module_name}/service"
  check_violation "repository" "internal/domain/${module_name}/handler"    "${module_name}/repository 不应引用 ${module_name}/handler"
  # types 层不应 import 任何上层
  check_violation "types"      "internal/domain/${module_name}/service"    "${module_name}/types 不应引用 ${module_name}/service"
  check_violation "types"      "internal/domain/${module_name}/repository" "${module_name}/types 不应引用 ${module_name}/repository"
  check_violation "types"      "internal/domain/${module_name}/handler"    "${module_name}/types 不应引用 ${module_name}/handler"
  # service 层不应 import handler
  check_violation "service"    "internal/domain/${module_name}/handler"    "${module_name}/service 不应引用 ${module_name}/handler"
done

echo "" >> "$REPORT_FILE"
if [[ $violations -eq 0 ]]; then
  echo "## 结论: ✅ 分层依赖方向合规" | tee -a "$REPORT_FILE"
  exit 0
else
  echo "## 结论: ❌ 发现 $violations 项分层违规，见上方清单" | tee -a "$REPORT_FILE"
  exit 1
fi
