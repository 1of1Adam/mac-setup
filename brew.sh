#!/usr/bin/env bash

# brew.sh — Homebrew 安装脚本
# 安装常用的开发工具和应用

echo "🍺 开始 Homebrew 安装..."
echo ""

###############################################################################
# 安装 Homebrew                                                               #
###############################################################################

if ! command -v brew &>/dev/null; then
    echo "📥 安装 Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Apple Silicon 配置
    if [[ -f /opt/homebrew/bin/brew ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
else
    echo "✅ Homebrew 已安装"
fi

# 更新 Homebrew
brew update

###############################################################################
# CLI 工具                                                                    #
###############################################################################

echo ""
echo "📦 安装 CLI 工具..."

CLI_TOOLS=(
    # 版本控制
    git
    gh              # GitHub CLI
    lazygit         # Git TUI

    # 现代 CLI 替代品
    eza             # ls 替代 (带图标)
    bat             # cat 替代 (语法高亮)
    fd              # find 替代
    ripgrep         # grep 替代
    fzf             # 模糊搜索
    zoxide          # cd 替代 (智能跳转)
    delta           # diff 替代 (git diff 美化)
    htop            # top 替代
    dust            # du 替代
    duf             # df 替代
    procs           # ps 替代
    sd              # sed 替代
    jq              # JSON 处理
    yq              # YAML 处理
    httpie          # curl 替代 (更友好)
    tldr            # man 替代 (简化版)

    # Shell
    zsh
    starship        # 终端提示符美化
    atuin           # Shell 历史管理

    # 开发语言
    node
    pnpm
    python
    go
    rust

    # 实用工具
    wget
    tree
    tmux
    neovim
    imagemagick
    ffmpeg
    pandoc
    shellcheck      # Shell 脚本检查

    # 网络工具
    nmap
    mtr
    wrk             # HTTP 压测
)

for tool in "${CLI_TOOLS[@]}"; do
    if brew list "$tool" &>/dev/null; then
        echo "  ✅ $tool"
    else
        echo "  📥 安装 $tool..."
        brew install "$tool"
    fi
done

###############################################################################
# GUI 应用 (Casks)                                                            #
###############################################################################

echo ""
echo "🖥️ 安装 GUI 应用..."

CASK_APPS=(
    # 浏览器
    google-chrome
    arc

    # 开发工具
    visual-studio-code
    iterm2
    docker
    postman

    # 效率工具
    raycast
    rectangle       # 窗口管理
    hiddenbar       # 菜单栏图标管理
    monitorcontrol  # 外接显示器亮度控制
    keka            # 压缩解压

    # 输入法
    squirrel        # Rime 鼠须管

    # 其他
    iina            # 视频播放器
    notion
    telegram
    discord
)

for app in "${CASK_APPS[@]}"; do
    if brew list --cask "$app" &>/dev/null; then
        echo "  ✅ $app"
    else
        echo "  📥 安装 $app..."
        brew install --cask "$app" 2>/dev/null || echo "    ⚠️ $app 安装失败或已通过其他方式安装"
    fi
done

###############################################################################
# 字体                                                                        #
###############################################################################

echo ""
echo "🔤 安装字体..."

# 添加字体 tap
brew tap homebrew/cask-fonts 2>/dev/null

FONTS=(
    font-fira-code-nerd-font
    font-jetbrains-mono-nerd-font
    font-hack-nerd-font
    font-meslo-lg-nerd-font
)

for font in "${FONTS[@]}"; do
    if brew list --cask "$font" &>/dev/null; then
        echo "  ✅ $font"
    else
        echo "  📥 安装 $font..."
        brew install --cask "$font" 2>/dev/null || echo "    ⚠️ $font 安装失败"
    fi
done

###############################################################################
# 清理                                                                        #
###############################################################################

echo ""
echo "🧹 清理..."
brew cleanup

echo ""
echo "✅ Homebrew 安装完成!"
echo ""
echo "已安装:"
echo "  - ${#CLI_TOOLS[@]} 个 CLI 工具"
echo "  - ${#CASK_APPS[@]} 个 GUI 应用"
echo "  - ${#FONTS[@]} 个 Nerd 字体"
