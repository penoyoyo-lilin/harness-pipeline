#!/bin/bash
#
# 安装流水线 Skills 到全局（Claude Code + ZCode）
#
# 同步目标：~/.claude/skills/（ZCode 通过符号链接自动跟随）
# 同步内容：
#   1. 栈中立 skills（从 registry.yaml 读取）→ ~/.claude/skills/<name>/
#   2. registry.yaml（单一真相源）→ ~/.claude/skills/registry.yaml
#   3. stacks/（所有 profile）→ ~/.claude/stacks/
#   4. 每个 profile 的 code-backend/code-frontend → ~/.claude/skills/<code_skill>/
#   5. 参考文档 weight-presets.md → ~/.claude/references/
#
# 命名策略：code-go(旧) 与 code-backend(新) 并存，互不覆盖
#

set -euo pipefail

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# 路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SKILLS_SRC="$PROJECT_ROOT/skills"
STACKS_SRC="$PROJECT_ROOT/stacks"
REGISTRY_SRC="$SKILLS_SRC/registry.yaml"

CLAUDE_HOME="$HOME/.claude"
SKILLS_DST="$CLAUDE_HOME/skills"
STACKS_DST="$CLAUDE_HOME/stacks"
REFS_DST="$CLAUDE_HOME/references"

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# 前置检查
if [[ ! -d "$SKILLS_SRC" ]]; then
    error "未找到 skills 目录：$SKILLS_SRC"
    error "请确保在 harness-pipeline 仓库根目录下运行此脚本"
    exit 1
fi

if [[ ! -f "$REGISTRY_SRC" ]]; then
    error "未找到 registry.yaml：$REGISTRY_SRC"
    exit 1
fi

mkdir -p "$SKILLS_DST" "$STACKS_DST" "$REFS_DST"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  安装 Harness Pipeline 到全局${NC}"
echo -e "${GREEN}  (Claude Code + ZCode 自动跟随)${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
info "源仓库:   $PROJECT_ROOT"
info "目标:     $CLAUDE_HOME"
echo ""

# ─── 1. 安装栈中立 skills（从 registry.yaml 读取）───
info "1/5 安装栈中立 skills..."
neutral_skills=$(python3 -c "
import yaml
d = yaml.safe_load(open('$REGISTRY_SRC'))
for s in d.get('skills', []):
    if s.get('location') == 'neutral':
        print(s['name'])
" 2>/dev/null || echo "analyze architect design-ui pipeline test review entropy modular-vibe-coding")

neutral_count=0
for skill in $neutral_skills; do
    if [[ -d "$SKILLS_SRC/$skill" ]]; then
        target="$SKILLS_DST/$skill"
        mkdir -p "$target"
        cp -r "$SKILLS_SRC/$skill/"* "$target/"
        cmd=$(grep -m1 "^command:" "$target/SKILL.md" 2>/dev/null | awk '{print $2}' || echo "$skill")
        success "  /$cmd ← skills/$skill/"
        ((neutral_count++))
    fi
done
echo ""

# ─── 2. 安装 registry.yaml ───
info "2/5 安装 registry.yaml（单一真相源）..."
cp "$REGISTRY_SRC" "$SKILLS_DST/registry.yaml"
success "  ~/.claude/skills/registry.yaml"
echo ""

# ─── 3. 安装 stacks/（所有 profile）───
info "3/5 安装 stacks/（技术栈 profile）..."
if [[ -d "$STACKS_SRC" ]]; then
    # 清理旧的全局 stacks（保留 lib/ 和文档）
    # 复制全部（覆盖）
    cp -r "$STACKS_SRC/"* "$STACKS_DST/"
    profile_count=$(find "$STACKS_DST" -maxdepth 1 -name "profile.yaml" 2>/dev/null | wc -l | tr -d ' ')
    # 实际是目录数
    profile_count=$(find "$STACKS_DST" -maxdepth 2 -name "profile.yaml" 2>/dev/null | wc -l | tr -d ' ')
    success "  ~/.claude/stacks/（$profile_count 个 profile + lib/）"
    find "$STACKS_DST" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
else
    warn "  stacks/ 目录不存在，跳过"
fi
echo ""

# ─── 4. 安装 profile 的 code skills（code-backend / code-frontend）───
info "4/5 安装 profile 编码 skills..."
code_count=0
for profile_yaml in "$STACKS_SRC"/*/profile.yaml; do
    [[ -f "$profile_yaml" ]] || continue
    profile_name=$(python3 -c "import yaml;print(yaml.safe_load(open('$profile_yaml'))['name'])" 2>/dev/null || basename "$(dirname "$profile_yaml")")

    for side in backend frontend; do
        code_skill=$(python3 -c "
import yaml
d = yaml.safe_load(open('$profile_yaml'))
v = d.get('$side', {})
print(v.get('code_skill', '') if v else '')
" 2>/dev/null || true)

        if [[ -z "$code_skill" ]]; then
            continue
        fi

        skill_src="$(dirname "$profile_yaml")/${side/'backend'/'backend'/'frontend'/'frontend'}"
        # 目录名是 code-backend / code-frontend
        skill_src="$(dirname "$profile_yaml")/code-${side}"
        if [[ -d "$skill_src" ]]; then
            target="$SKILLS_DST/$code_skill"
            # 命名策略：code-go(旧) 与 code-backend(新) 并存
            # 仅当目标不存在或目标名不是 code-go 时覆盖
            if [[ "$code_skill" == "code-go" && -d "$target" ]]; then
                warn "  保留旧版: ${code_skill} (不覆盖)"
            else
                mkdir -p "$target"
                cp -r "$skill_src/"* "$target/"
                success "  /$code_skill ← $profile_name/code-${side}/"
                ((code_count++))
            fi
        fi
    done
done
echo ""

# ─── 5. 安装参考文档 ───
info "5/5 安装参考文档..."
if [[ -f "$PROJECT_ROOT/docs/references/weight-presets.md" ]]; then
    cp "$PROJECT_ROOT/docs/references/weight-presets.md" "$REFS_DST/weight-presets.md"
    success "  ~/.claude/references/weight-presets.md"
fi
echo ""

# ─── 汇总 ───
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  安装完成${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "已安装到 ${CLAUDE_HOME}:"
echo "  栈中立 skills: $neutral_count 个"
echo "  profile 编码 skills: $code_count 个"
echo "  stacks/ profile: $profile_count 个 + lib/"
echo "  registry.yaml: ✅"
echo "  references/weight-presets.md: ✅"
echo ""

# ─── 同步 ZCode 符号链接 ───
# 仅为本仓库管理的 skill 建链接（栈中立 + profile code skills），不碰其他 skill
ZCODE_SKILLS="$HOME/.zcode/skills"
if [[ -d "$ZCODE_SKILLS" ]]; then
    info "同步 ZCode 符号链接 (~/.zcode/skills/ → ~/.claude/skills/)..."
    synced=0
    # 仅为本仓库的栈中立 skill + code-backend/code-frontend 建链接
    managed_skills="$neutral_skills code-backend code-frontend"
    for skill_name in $managed_skills; do
        skill_dir="$SKILLS_DST/$skill_name"
        zcode_link="$ZCODE_SKILLS/$skill_name"
        if [[ -d "$skill_dir" ]] && [[ ! -e "$zcode_link" ]]; then
            ln -s "$skill_dir" "$zcode_link"
            success "  新建链接: $skill_name"
            ((synced++))
        fi
    done
    if [[ $synced -eq 0 ]]; then
        info "  ZCode 链接已是最新，无需新建"
    else
        success "  ZCode 已同步 $synced 个新链接"
    fi
    # 同步 registry.yaml 链接
    if [[ ! -e "$ZCODE_SKILLS/registry.yaml" ]] && [[ -f "$SKILLS_DST/registry.yaml" ]]; then
        ln -s "$SKILLS_DST/registry.yaml" "$ZCODE_SKILLS/registry.yaml"
    fi
    echo ""
fi

warn "注意：全局 pipeline 已更新为 profile 驱动版。"
warn "      已初始化的项目使用项目级 .claude/skills/，不受影响。"
warn "      未初始化项目将使用全局新版 pipeline（向后兼容：无 profile 时跳过栈相关检查）。"
echo ""
