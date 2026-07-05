#!/bin/bash
#
# contract-diff.sh — 契约比对层（栈无关，所有 profile 共用）
#
# 用法: contract-diff.sh <left-file> <right-file> <left-label> <right-label> <report-file>
# 输入: 两个每行一条 "METHOD /path" 的文本文件
# 输出: 差异报告写入 report-file，退出码 0=一致 1=有漂移
#
set -euo pipefail

LEFT_FILE="${1:?用法: contract-diff.sh <left> <right> <left-label> <right-label> <report>}"
RIGHT_FILE="${2:?}"
LEFT_LABEL="${3:?}"
RIGHT_LABEL="${4:?}"
REPORT_FILE="${5:?}"

# 提取纯路径（忽略 METHOD），排序去重
left_paths=$(awk '{print $2}' "$LEFT_FILE" 2>/dev/null | sort -u || true)
right_paths=$(awk '{print $2}' "$RIGHT_FILE" 2>/dev/null | sort -u || true)

# 如果输入没有 METHOD 前缀（纯路径），直接用
if [[ -z "$left_paths" ]]; then
  left_paths=$(sort -u "$LEFT_FILE" 2>/dev/null || true)
fi
if [[ -z "$right_paths" ]]; then
  right_paths=$(sort -u "$RIGHT_FILE" 2>/dev/null || true)
fi

only_left=$(comm -23 <(echo "$left_paths") <(echo "$right_paths") || true)
only_right=$(comm -13 <(echo "$left_paths") <(echo "$right_paths") || true)

drift=0

{
  echo "## 差异分析"
  echo ""
  if [[ -n "$only_left" ]]; then
    echo "### 仅在 ${LEFT_LABEL} 存在（${RIGHT_LABEL} 缺失）"
    echo '```'
    echo "$only_left"
    echo '```'
    echo ""
    drift=1
  fi
  if [[ -n "$only_right" ]]; then
    echo "### 仅在 ${RIGHT_LABEL} 存在（${LEFT_LABEL} 未实现）"
    echo '```'
    echo "$only_right"
    echo '```'
    echo ""
    drift=1
  fi
} >> "$REPORT_FILE"

if [[ $drift -eq 0 ]]; then
  echo "## 结论: ✅ ${LEFT_LABEL} 与 ${RIGHT_LABEL} 一致" >> "$REPORT_FILE"
  exit 0
else
  echo "## 结论: ❌ 存在契约漂移，见上方差异" >> "$REPORT_FILE"
  exit 1
fi
