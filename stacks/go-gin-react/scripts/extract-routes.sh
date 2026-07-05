#!/bin/bash
#
# extract-routes.sh — 提取 Go 后端注册路由（go-gin-react profile 探测层）
#
# 用法: extract-routes.sh <project-dir>
# 输出: stdout 每行一条 "METHOD /path"，退出码 0
#
set -euo pipefail

PROJECT_DIR="${1:-.}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

# 匹配 Gin/Chi/Echo 路由注册: r.GET("/path"), r.POST("/path"), router.Get("/path") 等
grep -rhoE '\.(GET|POST|PUT|DELETE|PATCH|Get|Post|Put|Delete|Patch)\("(/[^"]+)"' "$PROJECT_DIR/internal/" 2>/dev/null \
  | sed -E 's/\.(GET|POST|PUT|DELETE|PATCH|Get|Post|Put|Delete|Patch)\("(.+)"/\1 \2/' \
  | awk '{print toupper($1), $2}' \
  | sort -u || true
