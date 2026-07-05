#!/bin/bash
#
# baseline-check.sh — Python FastAPI 分层依赖方向检查（python-fastapi-vue profile）
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

MODULES_DIR="$PROJECT_DIR/app/modules"

if [[ ! -d "$MODULES_DIR" ]]; then
  echo "SKIP: $MODULES_DIR 不存在（首次初始化或无后端代码）"
  exit 0
fi

violations=0
{
  echo "# Baseline Check — Python FastAPI 分层"
  echo ""
  echo "> 检查时间: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "> 检查范围: \`app/modules/*/\`"
  echo "> 说明: 检测 import 语句，排除 tests/"
  echo ""
} > "$REPORT_FILE"

check_violation() {
  local file_pattern="$1"
  local forbidden_import="$2"
  local desc="$3"
  local hits
  hits=$(grep -rnE "^(from|import)\s+.*${forbidden_import}" $file_pattern 2>/dev/null | grep -v '/tests/' || true)
  if [[ -n "$hits" ]]; then
    echo "FAIL: $desc" | tee -a "$REPORT_FILE"
    echo "$hits" | sed "s|$PROJECT_DIR/||" | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"
    violations=$((violations + 1))
  else
    echo "PASS: $desc" | tee -a "$REPORT_FILE"
  fi
}

# 依赖方向: routers → services → repositories → models/schemas（严格单向）
# Python 分层：routers.py 不应 import repositories.py；repositories.py 不应 import services.py/routers.py
for module_dir in "$MODULES_DIR"/*/; do
  [[ -d "$module_dir" ]] || continue
  module_name=$(basename "$module_dir")

  local_prefix="app.modules.${module_name}"

  # routers 不应 import repositories
  check_violation "$module_dir/routers.py" "${local_prefix}.repositories" "${module_name}/routers 不应引用 ${module_name}/repositories"
  # repositories 不应 import services/routers
  check_violation "$module_dir/repositories.py" "${local_prefix}.services" "${module_name}/repositories 不应引用 ${module_name}/services"
  check_violation "$module_dir/repositories.py" "${local_prefix}.routers" "${module_name}/repositories 不应引用 ${module_name}/routers"
  # models/schemas 不应 import 上层
  check_violation "$module_dir/models.py" "${local_prefix}.services" "${module_name}/models 不应引用 ${module_name}/services"
  check_violation "$module_dir/models.py" "${local_prefix}.repositories" "${module_name}/models 不应引用 ${module_name}/repositories"
  check_violation "$module_dir/schemas.py" "${local_prefix}.services" "${module_name}/schemas 不应引用 ${module_name}/services"
  # services 不应 import routers
  check_violation "$module_dir/services.py" "${local_prefix}.routers" "${module_name}/services 不应引用 ${module_name}/routers"
done

echo "" >> "$REPORT_FILE"
if [[ $violations -eq 0 ]]; then
  echo "## 结论: ✅ 分层依赖方向合规" | tee -a "$REPORT_FILE"
  exit 0
else
  echo "## 结论: ❌ 发现 $violations 项分层违规，见上方清单" | tee -a "$REPORT_FILE"
  exit 1
fi
