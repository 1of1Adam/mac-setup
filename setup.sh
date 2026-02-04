#!/bin/bash
#
# macOS 新电脑一键配置脚本
# 使用方法: curl -fsSL https://raw.githubusercontent.com/baoyuanpeng/mac-setup/main/setup.sh | bash
#

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

CURRENT_USER=$(whoami)

echo ""
echo "=========================================="
echo "   macOS 新电脑一键配置脚本"
echo "   用户: $CURRENT_USER"
echo "=========================================="
echo ""

# ============================================
# 1. 配置 sudo 免密码
# ============================================
setup_sudo_nopasswd() {
    log_info "配置 sudo 免密码..."

    SUDOERS_FILE="/etc/sudoers.d/$CURRENT_USER"
    SUDOERS_CONTENT="$CURRENT_USER ALL=(ALL) NOPASSWD: ALL"

    if [[ -f "$SUDOERS_FILE" ]]; then
        log_warn "sudoers 文件已存在，跳过"
    else
        echo "$SUDOERS_CONTENT" | sudo tee "$SUDOERS_FILE" > /dev/null
        sudo chmod 440 "$SUDOERS_FILE"
        log_info "sudo 免密码配置完成 ✓"
    fi
}

# ============================================
# 2. 移除登录密码（可选）
# ============================================
remove_login_password() {
    read -p "是否移除登录密码？(y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        read -s -p "请输入当前密码: " current_password
        echo ""

        if dscl . -authonly "$CURRENT_USER" "$current_password" 2>/dev/null; then
            dscl . -passwd "/Users/$CURRENT_USER" "$current_password" ""
            log_info "登录密码已移除 ✓"
        else
            log_error "密码验证失败"
            return 1
        fi
    else
        log_info "跳过移除登录密码"
    fi
}

# ============================================
# 3. 安装 Homebrew
# ============================================
install_homebrew() {
    if command -v brew &> /dev/null; then
        log_info "Homebrew 已安装，跳过"
    else
        log_info "安装 Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # 添加到 PATH (Apple Silicon)
        if [[ -f /opt/homebrew/bin/brew ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
        log_info "Homebrew 安装完成 ✓"
    fi
}

# ============================================
# 4. 安装常用工具
# ============================================
install_tools() {
    log_info "安装常用开发工具..."

    TOOLS=(
        git
        node
        pnpm
        python
        gh          # GitHub CLI
        jq
        ripgrep
        fzf
        eza         # 替代 ls
        bat         # 替代 cat
        fd          # 替代 find
    )

    for tool in "${TOOLS[@]}"; do
        if brew list "$tool" &>/dev/null; then
            log_info "$tool 已安装"
        else
            log_info "安装 $tool..."
            brew install "$tool"
        fi
    done

    log_info "常用工具安装完成 ✓"
}

# ============================================
# 5. 配置 Git
# ============================================
setup_git() {
    log_info "配置 Git..."

    read -p "Git 用户名 (回车跳过): " git_name
    read -p "Git 邮箱 (回车跳过): " git_email

    [[ -n "$git_name" ]] && git config --global user.name "$git_name"
    [[ -n "$git_email" ]] && git config --global user.email "$git_email"

    # 常用配置
    git config --global init.defaultBranch main
    git config --global pull.rebase false
    git config --global core.editor "code --wait"

    log_info "Git 配置完成 ✓"
}

# ============================================
# 6. 安装 Claude Code CLI
# ============================================
install_claude_code() {
    if command -v claude &> /dev/null; then
        log_info "Claude Code 已安装，跳过"
    else
        log_info "安装 Claude Code CLI..."
        npm install -g @anthropic-ai/claude-code
        log_info "Claude Code 安装完成 ✓"
    fi
}

# ============================================
# 主流程
# ============================================
main() {
    # sudo 免密码必须首先配置
    setup_sudo_nopasswd

    # 可选配置
    remove_login_password

    # 开发环境
    install_homebrew
    install_tools
    setup_git
    install_claude_code

    echo ""
    echo "=========================================="
    echo "   配置完成！"
    echo "=========================================="
    echo ""
    echo "已配置:"
    echo "  - sudo 免密码"
    echo "  - Homebrew + 常用工具"
    echo "  - Git"
    echo "  - Claude Code CLI"
    echo ""
}

# 运行
main "$@"
