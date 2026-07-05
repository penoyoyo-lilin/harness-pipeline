#!/bin/bash
#
# extract-routes.sh — 提取 Python FastAPI 后端注册路由（python-fastapi-vue profile 探测层）
#
# 用法: extract-routes.sh <project-dir>
# 输出: stdout 每行一条 "METHOD /path"，退出码 0
#
set -euo pipefail

PROJECT_DIR="${1:-.}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

# 匹配 FastAPI 路由装饰器: @router.get("/path"), @router.post("/path") 等
grep -rhoE '@router\.(get|post|put|delete|patch)\("(/[^"]+)"' "$PROJECT_DIR/app/" 2>/dev/null \
  | sed -E 's/@router\.(get|post|put|delete|patch)\("(.+)"/\1 \2/' \
  | awk '{print toupper($1), $2}' \
  | sort -u || true
