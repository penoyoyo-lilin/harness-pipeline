#!/bin/bash
#
# Harness Pipeline 项目初始化脚本
# 支持本地模式（从当前仓库复制）和远程模式（从 GitHub 下载）
# 支持技术栈 profile：--stack <profile-name>（默认 go-gin-react）
#

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
REPO_BASE="yourorg/harness-pipeline"  # 远程仓库地址（远程模式使用）
BRANCH="main"

# 默认技术栈（向后兼容：未指定 --stack 时使用 go-gin-react）
STACK="go-gin-react"

# 目标目录（默认为当前目录）
TARGET_DIR="."

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case "$1" in
        --stack)
            STACK="$2"
            shift 2
            ;;
        --stack=*)
            STACK="${1#*=}"
            shift
            ;;
        --help|-h)
            echo "用法: init.sh [TARGET_DIR] [--stack <profile-name>]"
            echo ""
            echo "参数:"
            echo "  TARGET_DIR    目标目录（默认当前目录）"
            echo "  --stack       技术栈 profile 名称（默认 go-gin-react）"
            echo ""
            echo "可用 profile:见 stacks/ 目录"
            exit 0
            ;;
        *)
            TARGET_DIR="$1"
            shift
            ;;
    esac
done

# 检测运行模式
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Profile 目录（本地模式下从仓库 stacks/ 读取）
PROFILE_DIR="$PROJECT_ROOT/stacks/$STACK"
PROFILE_FILE="$PROFILE_DIR/profile.yaml"

# 打印函数
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查是否在 Harness Pipeline 项目内
if [[ -f "$PROJECT_ROOT/AGENTS.md" ]]; then
    MODE="local"
    SOURCE_DIR="$PROJECT_ROOT"
    echo -e "${BLUE}检测到本地 Harness Pipeline 仓库，使用本地模式${NC}"
else
    MODE="remote"
    SOURCE_DIR=""
    echo -e "${BLUE}使用远程模式（从 GitHub 下载）${NC}"
fi

# 校验 profile 存在（仅本地模式，因为远程模式按需下载）
if [[ "$MODE" == "local" ]]; then
    if [[ ! -f "$PROFILE_FILE" ]]; then
        error "Profile 不存在: $STACK"
        echo "  查找路径: $PROFILE_FILE"
        echo "  可用 profile: $(ls "$PROJECT_ROOT/stacks/" 2>/dev/null | grep -v '\.md$' | tr '\n' ' ')"
        exit 1
    fi
    info "使用技术栈 profile: ${STACK}"
fi

# 读取 profile 字段（需 python3 + yaml；不可用时回退到 grep）
read_profile_field() {
    local field_path="$1"
    if command -v python3 &>/dev/null && python3 -c "import yaml" 2>/dev/null; then
        python3 -c "
import yaml
d = yaml.safe_load(open('$PROFILE_FILE'))
parts = '$field_path'.split('.')
v = d
for p in parts:
    v = v.get(p) if isinstance(v, dict) else None
    if v is None: break
print('' if v is None else v)
" 2>/dev/null || true
    else
        # 回退：简单 grep（仅支持二级字段如 scaffold.dirs 不适用，此处用于标量）
        local key
        key=$(echo "$field_path" | sed 's/\./: /')
        grep -E "^\s*${key}" "$PROFILE_FILE" 2>/dev/null | head -1 | sed 's/.*:\s*//' | tr -d '"' || true
    fi
}

# 从 profile 的 scaffold.dirs 读取目录列表（每行一个）
read_profile_dirs() {
    if [[ ! -f "$PROFILE_FILE" ]]; then
        return
    fi
    if command -v python3 &>/dev/null && python3 -c "import yaml" 2>/dev/null; then
        python3 -c "
import yaml
d = yaml.safe_load(open('$PROFILE_FILE'))
for dd in d.get('scaffold', {}).get('dirs', []):
    print(dd)
" 2>/dev/null || true
    fi
}

# 创建目录结构
create_directories() {
    info "创建目录结构 (profile: ${STACK})..."

    local dirs=()

    if [[ "$MODE" == "local" ]]; then
        # 从 profile.yaml 的 scaffold.dirs 读取
        while IFS= read -r line; do
            [[ -n "$line" ]] && dirs+=("$line")
        done < <(read_profile_dirs)

        # GitHub Actions 目录（profile 无关，始终创建）
        dirs+=(".github/workflows")
    else
        # 远程模式：使用默认目录集（与 go-gin-react 一致）
        dirs=(
            ".harness/tasks" ".harness/artifacts" ".harness/logs" ".harness/reports"
            "docs/modules" "docs/api-specs" "docs/requirements"
            "docs/design-docs/adr" "docs/ui-prototypes" "docs/design-specs"
            "docs/plans" "docs/references" "docs/templates"
            "internal/domain" "src/app"
            ".github/workflows"
        )
    fi

    for dir in "${dirs[@]}"; do
        mkdir -p "$TARGET_DIR/$dir"
    done

    success "目录结构创建完成（${#dirs[@]} 个目录）"
}

# 本地模式：复制文件
copy_local_files() {
    info "从本地仓库复制文件..."

    # 核心文件
    cp "$SOURCE_DIR/AGENTS.md" "$TARGET_DIR/" 2>/dev/null || warn "AGENTS.md 复制失败"
    cp "$SOURCE_DIR/CLAUDE.md" "$TARGET_DIR/" 2>/dev/null || warn "CLAUDE.md 复制失败"
    cp "$SOURCE_DIR/AGENTS.override.md" "$TARGET_DIR/" 2>/dev/null || warn "AGENTS.override.md 复制失败"
    cp "$SOURCE_DIR/dashboard.html" "$TARGET_DIR/" 2>/dev/null || warn "dashboard.html 复制失败"

    # 方法论 Skills（栈无关，从 registry.yaml 读取列表）
    if [[ -d "$SOURCE_DIR/skills" ]]; then
        mkdir -p "$TARGET_DIR/.claude/skills"

        # 从 registry.yaml 读取 location=neutral 的 skill 列表
        if [[ -f "$SOURCE_DIR/skills/registry.yaml" ]]; then
            neutral_skills=$(python3 -c "
import yaml
d = yaml.safe_load(open('$SOURCE_DIR/skills/registry.yaml'))
for s in d.get('skills', []):
    if s.get('location') == 'neutral':
        print(s['name'])
" 2>/dev/null || echo "analyze architect design-ui test review entropy pipeline modular-vibe-coding")
        else
            # 回退：registry.yaml 不存在时用默认列表
            neutral_skills="analyze architect design-ui test review entropy pipeline modular-vibe-coding"
        fi

        for skill in $neutral_skills; do
            if [[ -d "$SOURCE_DIR/skills/$skill" ]]; then
                cp -r "$SOURCE_DIR/skills/$skill" "$TARGET_DIR/.claude/skills/" 2>/dev/null || true
            fi
        done

        # 复制 registry.yaml 本身（供 pipeline 运行时读取）
        cp "$SOURCE_DIR/skills/registry.yaml" "$TARGET_DIR/.claude/skills/registry.yaml" 2>/dev/null || true

        success "方法论 Skills 复制完成（从 registry.yaml 读取）"
    fi

    # Profile 相关：编码 skills + scripts（按 profile 动态复制）
    if [[ -d "$PROFILE_DIR" ]]; then
        # 复制 code-backend skill（如存在）
        if [[ -d "$PROFILE_DIR/code-backend" ]]; then
            mkdir -p "$TARGET_DIR/.claude/skills/code-backend"
            cp -r "$PROFILE_DIR/code-backend/"* "$TARGET_DIR/.claude/skills/code-backend/" 2>/dev/null || true
            success "code-backend skill 复制完成（来自 $STACK profile）"
        fi

        # 复制 code-frontend skill（如存在）
        if [[ -d "$PROFILE_DIR/code-frontend" ]]; then
            mkdir -p "$TARGET_DIR/.claude/skills/code-frontend"
            cp -r "$PROFILE_DIR/code-frontend/"* "$TARGET_DIR/.claude/skills/code-frontend/" 2>/dev/null || true
            success "code-frontend skill 复制完成（来自 $STACK profile）"
        fi

        # 复制 profile scripts 到项目的 .harness/scripts/
        if [[ -d "$PROFILE_DIR/scripts" ]]; then
            mkdir -p "$TARGET_DIR/.harness/scripts"
            cp -r "$PROFILE_DIR/scripts/"* "$TARGET_DIR/.harness/scripts/" 2>/dev/null || true
            chmod +x "$TARGET_DIR/.harness/scripts/"*.sh 2>/dev/null || true
            success "Profile scripts 复制完成（.harness/scripts/）"
        fi

        # 复制 profile.yaml 到项目（供 pipeline 运行时读取）
        cp "$PROFILE_FILE" "$TARGET_DIR/.harness/profile.yaml" 2>/dev/null || true
        success "Profile 配置复制完成（.harness/profile.yaml）"
    fi

    # 文档模板
    if [[ -d "$SOURCE_DIR/docs" ]]; then
        for subdir in templates references; do
            if [[ -d "$SOURCE_DIR/docs/$subdir" ]]; then
                cp -r "$SOURCE_DIR/docs/$subdir"/* "$TARGET_DIR/docs/$subdir/" 2>/dev/null || true
            fi
        done
        success "文档模板复制完成"
    fi

    # 示例文档（可选）- 非交互式环境自动跳过
    if [[ -d "$SOURCE_DIR/docs/requirements" ]] && [[ -t 0 ]]; then
        local example_files=()
        for f in "$SOURCE_DIR/docs/requirements/"*.md; do
            [[ "$(basename "$f")" != "_index.md" ]] && example_files+=("$f")
        done

        if [[ ${#example_files[@]} -gt 0 ]]; then
            info "发现示例需求文档，是否复制? [y/N]"
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                cp "${example_files[@]}" "$TARGET_DIR/docs/requirements/" 2>/dev/null || true
                success "示例文档复制完成"
            fi
        fi
    fi

    # GitHub Actions 模板
    if [[ -d "$SOURCE_DIR/.github/workflows" ]]; then
        cp -r "$SOURCE_DIR/.github/workflows"/* "$TARGET_DIR/.github/workflows/" 2>/dev/null || true
        success "GitHub Actions 模板复制完成"
    fi
}

# 远程模式：下载文件
download_remote_files() {
    info "从远程仓库下载文件..."

    local base_url="https://raw.githubusercontent.com/${REPO_BASE}/${BRANCH}"

    if ! command -v curl &> /dev/null; then
        error "curl 未安装，请先安装 curl"
        exit 1
    fi

    # 下载核心文件
    info "下载核心配置文件..."
    curl -fsSL "${base_url}/AGENTS.md" -o "$TARGET_DIR/AGENTS.md" || warn "AGENTS.md 下载失败"
    curl -fsSL "${base_url}/CLAUDE.md" -o "$TARGET_DIR/CLAUDE.md" || warn "CLAUDE.md 下载失败"
    curl -fsSL "${base_url}/AGENTS.override.md" -o "$TARGET_DIR/AGENTS.override.md" || warn "AGENTS.override.md 下载失败"
    curl -fsSL "${base_url}/dashboard.html" -o "$TARGET_DIR/dashboard.html" || warn "dashboard.html 下载失败"

    # 下载方法论 Skills（栈无关）
    # 注意：此列表须与 skills/registry.yaml 的 location=neutral 条目保持一致
    info "下载方法论 Skills..."
    local neutral_skills=("analyze" "architect" "design-ui" "test" "review" "entropy" "pipeline" "modular-vibe-coding")
    for skill in "${neutral_skills[@]}"; do
        mkdir -p "$TARGET_DIR/.claude/skills/$skill"
        curl -fsSL "${base_url}/skills/${skill}/SKILL.md" -o "$TARGET_DIR/.claude/skills/$skill/SKILL.md" 2>/dev/null || warn "Skill $skill 下载失败"
    done
    # 下载 registry.yaml（单一真相源）
    curl -fsSL "${base_url}/skills/registry.yaml" -o "$TARGET_DIR/.claude/skills/registry.yaml" 2>/dev/null || warn "registry.yaml 下载失败"

    # 下载 Profile 相关（code-backend / code-frontend / scripts / profile.yaml）
    info "下载 $STACK profile..."
    local profile_base="${base_url}/stacks/${STACK}"
    # profile.yaml
    curl -fsSL "${profile_base}/profile.yaml" -o "$TARGET_DIR/.harness/profile.yaml" 2>/dev/null || warn "profile.yaml 下载失败"
    # code-backend
    mkdir -p "$TARGET_DIR/.claude/skills/code-backend"
    curl -fsSL "${profile_base}/code-backend/SKILL.md" -o "$TARGET_DIR/.claude/skills/code-backend/SKILL.md" 2>/dev/null || warn "code-backend 下载失败"
    # code-frontend
    mkdir -p "$TARGET_DIR/.claude/skills/code-frontend"
    curl -fsSL "${profile_base}/code-frontend/SKILL.md" -o "$TARGET_DIR/.claude/skills/code-frontend/SKILL.md" 2>/dev/null || warn "code-frontend 下载失败"

    # 下载文档模板
    info "下载文档模板..."
    local templates=("requirement.md" "prb.md" "architecture.md" "module-plan.md" "ui-spec.md" "openapi.yaml")
    for template in "${templates[@]}"; do
        curl -fsSL "${base_url}/docs/templates/${template}" -o "$TARGET_DIR/docs/templates/${template}" 2>/dev/null || true
    done

    # 下载参考文档
    local refs=("go-conventions.md" "nextjs-conventions.md" "frontend-conventions.md" "ci-cd.md")
    for ref in "${refs[@]}"; do
        curl -fsSL "${base_url}/docs/references/${ref}" -o "$TARGET_DIR/docs/references/${ref}" 2>/dev/null || true
    done

    success "远程文件下载完成"
}

# 初始化模块索引
init_module_index() {
    local index_file="$TARGET_DIR/docs/modules/_index.md"

    if [[ ! -f "$index_file" ]]; then
        info "初始化模块索引..."
        cat > "$index_file" << 'EOF'
# 模块索引

> **自动维护**：此文件由流水线 Skill 自动更新，请勿手动编辑。

| 模块 | 状态 | 需求文档 | 架构文档 | UI 原型 | 测试状态 | 审查状态 | 产出时间 |
|------|------|---------|---------|---------|---------|---------|---------|
<!-- 流水线自动追加模块条目 -->
EOF
        success "模块索引初始化完成"
    fi
}

# 创建 .gitignore
create_gitignore() {
    local gitignore_file="$TARGET_DIR/.gitignore"

    if [[ ! -f "$gitignore_file" ]]; then
        info "创建 .gitignore..."
        cat > "$gitignore_file" << 'EOF'
# Dependencies
node_modules/
vendor/

# Build outputs
dist/
build/
*.exe
*.dll
*.so

# Environment
.env
.env.local
.env.*.local

# IDE
.idea/
.vscode/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Logs
*.log
logs/

# Test coverage
coverage/
*.cover

# Harness runtime
.harness/logs/
.harness/artifacts/
.harness/reports/
EOF
        success ".gitignore 创建完成"
    fi
}

# 创建 README
create_readme() {
    local readme_file="$TARGET_DIR/README.md"

    if [[ ! -f "$readme_file" ]]; then
        info "创建 README.md..."
        cat > "$readme_file" << EOF
# 项目初始化完成

本项目已配置 Harness Pipeline Agent Team 自动化产研流水线。

## 技术栈

**Profile**: ${STACK}

## 快速开始

\`\`\`bash
# 启动完整流水线（需求→设计→编码→测试→审查）
/pipeline "实现你的第一个功能"

# 单步调用
/analyze 需求描述                    # 需求分析
/architect 需求文档路径               # 架构设计 + 契约
/design-ui 需求描述                   # UI 设计
/code-backend 架构设计路径            # 后端编码（按 profile）
/code-frontend 架构设计路径           # 前端编码（按 profile）
/test 代码路径                        # 测试
/review 代码路径                      # 代码审查
/entropy                              # 代码健康扫描
/pipeline "需求描述"                  # 端到端编排
\`\`\`

## 项目结构

\`\`\`
AGENTS.md                     # Lead Agent 总调度
CLAUDE.md                     # 流水线执行指令
.claude/skills/               # Agent Skills
.harness/                     # Agent 共享数据
  ├── tasks/                  # 任务状态文件
  ├── profile.yaml            # 技术栈 profile（本项目的栈声明）
  ├── scripts/                # 栈相关脚本（基线检查/契约同步/集成测试）
  ├── artifacts/              # 中间产物
  └── logs/                   # 执行日志
docs/                         # 文档体系
  ├── modules/_index.md       # 模块索引
  ├── api-specs/              # 契约文件
  ├── requirements/           # 需求文档
  ├── design-docs/            # 架构设计
  ├── ui-prototypes/          # UI 原型
  ├── references/             # 编码规范
  └── templates/              # 文档模板
\`\`\`

---

*Generated by Harness Pipeline Init Script (profile: ${STACK})*
EOF
        success "README.md 创建完成"
    fi
}

# 打印使用说明
print_usage() {
    echo ""
    echo -e "${GREEN}====================================${NC}"
    echo -e "${GREEN}  Harness Pipeline 初始化完成！${NC}"
    echo -e "${GREEN}====================================${NC}"
    echo ""
    echo "项目位置: $(cd "$TARGET_DIR" && pwd)"
    echo "技术栈:   $STACK"
    echo ""
    echo "下一步:"
    echo "  1. cd $(cd "$TARGET_DIR" && pwd)"
    echo "  2. /pipeline \"实现你的第一个功能\""
    echo ""
    echo "查看 Dashboard:"
    echo "  open dashboard.html"
    echo ""
}

# 主函数
main() {
    echo -e "${GREEN}====================================${NC}"
    echo -e "${GREEN}  Harness Pipeline 项目初始化${NC}"
    echo -e "${GREEN}====================================${NC}"
    echo ""

    create_directories

    if [[ "$MODE" == "local" ]]; then
        copy_local_files
    else
        download_remote_files
    fi

    init_module_index
    create_gitignore
    create_readme
    print_usage
}

# 运行主函数
main
