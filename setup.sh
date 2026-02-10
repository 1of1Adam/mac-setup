#!/bin/bash
#
# macOS 新电脑一键配置脚本
# 使用方法: curl -fsSL https://raw.githubusercontent.com/1of1Adam/dotfiles/main/setup.sh | bash
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
# 2. 禁用 Gatekeeper（允许任何来源的 App）
# ============================================
disable_gatekeeper() {
    log_info "禁用 Gatekeeper..."

    # 检查当前状态
    if spctl --status 2>/dev/null | grep -q "disabled"; then
        log_info "Gatekeeper 已禁用，跳过"
    else
        # 禁用 Gatekeeper
        sudo spctl --master-disable 2>/dev/null || true

        # 设置允许任何来源（通过 defaults 写入偏好设置）
        sudo defaults write /Library/Preferences/com.apple.security GKAutoRearm -bool false 2>/dev/null || true
        sudo defaults write /Library/Preferences/com.apple.security LSQuarantine -bool false 2>/dev/null || true

        log_info "Gatekeeper 已禁用 ✓"
        log_warn "注意：首次运行仍需在系统设置 → 隐私与安全性中手动确认 '任何来源'"
    fi
}

# ============================================
# 3. 移除登录密码（可选）
# ============================================
remove_login_password() {
    read -p "是否移除登录密码？(y/N): " confirm < /dev/tty
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        read -s -p "请输入当前密码: " current_password < /dev/tty
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
        ripgrep     # 替代 grep
        fzf         # 模糊搜索
        fswatch     # 监听 Downloads（AutoInstaller 依赖）
        eza         # 替代 ls
        bat         # 替代 cat
        fd          # 替代 find
        zoxide      # 替代 cd，智能目录跳转
        atuin       # shell 历史管理
        starship    # 终端 prompt 美化
        delta       # git diff 美化
        lazygit     # git TUI
        htop        # 替代 top
        dust        # 替代 du
        duf         # 替代 df
        procs       # 替代 ps
        httpie      # 替代 curl (更友好)
        tldr        # 替代 man (简化版)
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

    read -p "Git 用户名 (回车跳过): " git_name < /dev/tty
    read -p "Git 邮箱 (回车跳过): " git_email < /dev/tty

    [[ -n "$git_name" ]] && git config --global user.name "$git_name"
    [[ -n "$git_email" ]] && git config --global user.email "$git_email"

    # 常用配置
    git config --global init.defaultBranch main
    git config --global pull.rebase false
    git config --global core.editor "code --wait"

    log_info "Git 配置完成 ✓"
}

# ============================================
# 6. 安装 Google Chrome
# ============================================
install_chrome() {
    if [[ -d "/Applications/Google Chrome.app" ]]; then
        log_info "Google Chrome 已安装，跳过"
    else
        log_info "安装 Google Chrome..."
        brew install --cask google-chrome
        log_info "Google Chrome 安装完成 ✓"
    fi
}

# ============================================
# 7. 安装 Claude Code CLI
# ============================================
install_claude_code() {
    if command -v claude &> /dev/null; then
        log_info "Claude Code 已安装，跳过"
    else
        log_info "安装 Claude Code CLI..."
        curl -fsSL https://claude.ai/install.sh | bash
        log_info "Claude Code 安装完成 ✓"
    fi
}

# ============================================
# 8. 安装 OpenAI Codex CLI
# ============================================
install_codex() {
    if command -v codex &> /dev/null; then
        log_info "OpenAI Codex 已安装，跳过"
    else
        log_info "安装 OpenAI Codex CLI..."
        npm i -g @openai/codex
        log_info "OpenAI Codex 安装完成 ✓"
    fi
}

# ============================================
# 9. 安装 VS Code
# ============================================
install_vscode() {
    if [[ -d "/Applications/Visual Studio Code.app" ]]; then
        log_info "VS Code 已安装，跳过"
    else
        log_info "安装 VS Code..."
        brew install --cask visual-studio-code
        log_info "VS Code 安装完成 ✓"
    fi
}

# ============================================
# 10. 安装 Raycast
# ============================================
install_raycast() {
    if [[ -d "/Applications/Raycast.app" ]]; then
        log_info "Raycast 已安装，跳过"
    else
        log_info "安装 Raycast..."
        brew install --cask raycast
        log_info "Raycast 安装完成 ✓"
    fi
}

# ============================================
# 11. macOS 系统优化
# ============================================
setup_macos_defaults() {
    log_info "配置 macOS 系统优化..."

    # 加快键盘重复速度
    defaults write NSGlobalDomain KeyRepeat -int 1
    defaults write NSGlobalDomain InitialKeyRepeat -int 10

    # 显示隐藏文件
    defaults write com.apple.finder AppleShowAllFiles YES

    # 禁止在网络卷上生成 .DS_Store
    defaults write com.apple.desktopservices DSDontWriteNetworkStores true

    log_info "macOS 系统优化完成 ✓ (部分设置需要重启生效)"
}

# ============================================
# 12. 配置 .zshrc
# ============================================
setup_zshrc() {
    log_info "配置 .zshrc..."

    # 备份现有 .zshrc
    if [[ -f ~/.zshrc ]]; then
        cp ~/.zshrc ~/.zshrc.backup.$(date +%Y%m%d%H%M%S)
        log_info "已备份现有 .zshrc"
    fi

    # 下载 .zshrc 模板
    curl -fsSL https://raw.githubusercontent.com/1of1Adam/dotfiles/main/zshrc -o ~/.zshrc

    log_info ".zshrc 配置完成 ✓"
}

# ============================================
# 13. 安装 Rime 鼠须管输入法
# ============================================
install_rime() {
    if [[ -d "/Library/Input Methods/Squirrel.app" ]]; then
        log_info "Rime 鼠须管已安装"
    else
        log_info "安装 Rime 鼠须管..."
        brew install --cask squirrel
        log_info "Rime 鼠须管安装完成 ✓"
    fi

    # 恢复 Rime 配置
    log_info "恢复 Rime 配置..."
    mkdir -p ~/Library/Rime

    # 下载配置（排除 build 和 userdb）
    RIME_URL="https://raw.githubusercontent.com/1of1Adam/dotfiles/main/rime"

    # 使用 git sparse checkout 下载 rime 目录
    cd /tmp
    rm -rf dotfiles-rime 2>/dev/null
    git clone --depth 1 --filter=blob:none --sparse https://github.com/1of1Adam/dotfiles.git dotfiles-rime
    cd dotfiles-rime
    git sparse-checkout set rime
    cp -r rime/* ~/Library/Rime/
    rm -rf /tmp/dotfiles-rime

    log_info "Rime 配置恢复完成 ✓ (请重新部署: 右键点击输入法图标 → 重新部署)"
}

# ============================================
# 主流程
# ============================================
main() {
    # sudo 免密码必须首先配置
    setup_sudo_nopasswd

    # 禁用 Gatekeeper（允许运行任何来源的 App）
    disable_gatekeeper

    # 可选配置
    remove_login_password

    # 开发环境
    install_homebrew
    install_tools
    install_chrome
    install_vscode
    install_raycast
    setup_git
    install_claude_code
    install_codex

    # 系统配置
    setup_macos_defaults
    setup_zshrc
    install_rime

    echo ""
    echo "=========================================="
    echo "   配置完成！"
    echo "=========================================="
    echo ""
    echo "已配置:"
    echo "  - sudo 免密码"
    echo "  - Gatekeeper 禁用（允许任何来源 App）"
    echo "  - Homebrew + 常用工具"
    echo "  - Google Chrome"
    echo "  - VS Code"
    echo "  - Raycast"
    echo "  - Git"
    echo "  - Claude Code CLI"
    echo "  - OpenAI Codex CLI"
    echo "  - macOS 系统优化 (键盘速度等)"
    echo "  - .zshrc 配置"
    echo "  - Rime 鼠须管输入法 + 配置"
    echo ""
    echo "提示:"
    echo "  - 部分设置需要重启或重新登录生效"
    echo "  - Rime 输入法需要手动重新部署"
    echo ""
}

# 运行
main "$@"
