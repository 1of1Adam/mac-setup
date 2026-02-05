#!/usr/bin/env bash

# setup.sh — macOS 新电脑一键配置
#
# 使用方法:
#   curl -fsSL https://raw.githubusercontent.com/1of1Adam/dotfiles/main/setup.sh | bash
#
# 或者克隆后运行:
#   git clone https://github.com/1of1Adam/dotfiles.git ~/.dotfiles
#   cd ~/.dotfiles && ./setup.sh

set -e

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}✓${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }
log_section() { echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n${BLUE}▶ $1${NC}\n"; }

CURRENT_USER=$(whoami)
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}         ${GREEN}macOS 新电脑一键配置脚本${NC}                    ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}         用户: ${YELLOW}$CURRENT_USER${NC}                               ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"

###############################################################################
# 克隆或更新 dotfiles                                                          #
###############################################################################

log_section "准备 Dotfiles"

if [[ -d "$DOTFILES_DIR/.git" ]]; then
    log_info "更新 dotfiles..."
    git -C "$DOTFILES_DIR" pull origin main 2>/dev/null || true
else
    log_info "克隆 dotfiles 到 $DOTFILES_DIR..."
    rm -rf "$DOTFILES_DIR"
    git clone https://github.com/1of1Adam/dotfiles.git "$DOTFILES_DIR"
fi

cd "$DOTFILES_DIR"

###############################################################################
# 1. sudo 免密码                                                              #
###############################################################################

log_section "配置 sudo 免密码"

SUDOERS_FILE="/etc/sudoers.d/$CURRENT_USER"

if [[ -f "$SUDOERS_FILE" ]]; then
    log_warn "sudoers 文件已存在，跳过"
else
    echo "$CURRENT_USER ALL=(ALL) NOPASSWD: ALL" | sudo tee "$SUDOERS_FILE" >/dev/null
    sudo chmod 440 "$SUDOERS_FILE"
    log_info "sudo 免密码配置完成"
fi

###############################################################################
# 2. 可选：移除登录密码                                                        #
###############################################################################

log_section "登录密码设置"

read -p "是否移除登录密码？(y/N): " confirm </dev/tty || confirm="n"
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    read -s -p "请输入当前密码: " current_password </dev/tty
    echo ""
    if dscl . -authonly "$CURRENT_USER" "$current_password" 2>/dev/null; then
        dscl . -passwd "/Users/$CURRENT_USER" "$current_password" ""
        log_info "登录密码已移除"
    else
        log_error "密码验证失败"
    fi
else
    log_info "跳过移除登录密码"
fi

###############################################################################
# 3. Homebrew 和工具                                                          #
###############################################################################

log_section "安装 Homebrew 和工具"

if [[ -f "$DOTFILES_DIR/brew.sh" ]]; then
    chmod +x "$DOTFILES_DIR/brew.sh"
    "$DOTFILES_DIR/brew.sh"
else
    # Fallback: 直接安装
    if ! command -v brew &>/dev/null; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        if [[ -f /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    fi
fi

###############################################################################
# 4. Git 配置                                                                 #
###############################################################################

log_section "配置 Git"

read -p "Git 用户名 (回车跳过): " git_name </dev/tty || git_name=""
read -p "Git 邮箱 (回车跳过): " git_email </dev/tty || git_email=""

[[ -n "$git_name" ]] && git config --global user.name "$git_name"
[[ -n "$git_email" ]] && git config --global user.email "$git_email"

# Git 配置
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.editor "code --wait"

# Delta 美化配置 (如果安装了 delta)
if command -v delta &>/dev/null; then
    git config --global core.pager delta
    git config --global interactive.diffFilter "delta --color-only"
    git config --global delta.navigate true
    git config --global delta.light false
    git config --global delta.side-by-side true
    git config --global merge.conflictstyle diff3
    git config --global diff.colorMoved default
fi

log_info "Git 配置完成"

###############################################################################
# 5. AI 工具                                                                  #
###############################################################################

log_section "安装 AI 工具"

# Claude Code
if command -v claude &>/dev/null; then
    log_info "Claude Code 已安装"
else
    log_info "安装 Claude Code CLI..."
    curl -fsSL https://claude.ai/install.sh | bash 2>/dev/null || log_warn "Claude Code 安装失败"
fi

# OpenAI Codex
if command -v codex &>/dev/null; then
    log_info "OpenAI Codex 已安装"
elif command -v npm &>/dev/null; then
    log_info "安装 OpenAI Codex CLI..."
    npm i -g @openai/codex 2>/dev/null || log_warn "Codex 安装失败"
fi

###############################################################################
# 6. 链接配置文件                                                              #
###############################################################################

log_section "链接配置文件"

link_file() {
    local src="$1"
    local dst="$2"

    if [[ ! -f "$src" ]]; then
        return
    fi

    if [[ -f "$dst" ]] && [[ ! -L "$dst" ]]; then
        log_warn "备份 $dst"
        mv "$dst" "$dst.backup.$(date +%Y%m%d%H%M%S)"
    fi

    ln -sf "$src" "$dst"
    log_info "链接 $(basename "$src") -> $dst"
}

# 链接 dotfiles
link_file "$DOTFILES_DIR/.aliases" "$HOME/.aliases"
link_file "$DOTFILES_DIR/.functions" "$HOME/.functions"

# 创建 zshrc 如果不存在
if [[ -f "$DOTFILES_DIR/zshrc" ]]; then
    link_file "$DOTFILES_DIR/zshrc" "$HOME/.zshrc"
elif [[ ! -f "$HOME/.zshrc" ]]; then
    # 创建基础 .zshrc
    cat >"$HOME/.zshrc" <<'EOF'
# ~/.zshrc

# 加载 dotfiles
[[ -f ~/.aliases ]] && source ~/.aliases
[[ -f ~/.functions ]] && source ~/.functions

# Homebrew
if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# 现代 CLI 工具
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"
command -v starship &>/dev/null && eval "$(starship init zsh)"
command -v atuin &>/dev/null && eval "$(atuin init zsh)"

# fzf
[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh

# 历史记录
HISTSIZE=50000
SAVEHIST=50000
HISTFILE=~/.zsh_history
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE

# 补全
autoload -Uz compinit && compinit

# 快捷键
bindkey -e
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward
EOF
    log_info "创建 ~/.zshrc"
fi

###############################################################################
# 7. macOS 系统设置                                                           #
###############################################################################

log_section "应用 macOS 系统设置"

if [[ -f "$DOTFILES_DIR/.macos" ]]; then
    chmod +x "$DOTFILES_DIR/.macos"
    "$DOTFILES_DIR/.macos"
else
    log_warn "未找到 .macos 文件，跳过"
fi

###############################################################################
# 8. Rime 输入法                                                              #
###############################################################################

log_section "配置 Rime 输入法"

if [[ ! -d "/Library/Input Methods/Squirrel.app" ]]; then
    log_info "安装 Rime 鼠须管..."
    brew install --cask squirrel 2>/dev/null || log_warn "Rime 安装失败"
else
    log_info "Rime 鼠须管已安装"
fi

# 恢复 Rime 配置
if [[ -d "$DOTFILES_DIR/rime" ]]; then
    log_info "恢复 Rime 配置..."
    mkdir -p ~/Library/Rime
    cp -r "$DOTFILES_DIR/rime/"* ~/Library/Rime/ 2>/dev/null || true
    log_info "Rime 配置恢复完成"
    log_warn "请手动重新部署 Rime: 右键点击输入法图标 → 重新部署"
fi

###############################################################################
# 完成                                                                        #
###############################################################################

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}              ${GREEN}🎉 配置完成！${NC}                          ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}已配置:${NC}"
echo "  ✅ sudo 免密码"
echo "  ✅ Homebrew + 现代 CLI 工具 (eza, bat, fd, rg, fzf...)"
echo "  ✅ GUI 应用 (Chrome, VS Code, Raycast, iTerm2...)"
echo "  ✅ Nerd 字体"
echo "  ✅ Git + Delta 美化"
echo "  ✅ Claude Code + OpenAI Codex"
echo "  ✅ macOS 系统优化 (100+ 项设置)"
echo "  ✅ Shell 别名和函数 (.aliases, .functions)"
echo "  ✅ Rime 鼠须管输入法 + 雾凇拼音"
echo ""
echo -e "${YELLOW}💡 提示:${NC}"
echo "  • 运行 ${CYAN}source ~/.zshrc${NC} 或重启终端加载新配置"
echo "  • 部分设置需要注销/重启才能完全生效"
echo "  • Rime 输入法需要手动重新部署"
echo ""
echo -e "${BLUE}📁 Dotfiles 位置:${NC} $DOTFILES_DIR"
echo ""
