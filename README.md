# dotfiles

> macOS 新电脑一键配置 · 基于 [mathiasbynens/dotfiles](https://github.com/mathiasbynens/dotfiles) 精选

## 🚀 快速开始

```bash
curl -fsSL https://raw.githubusercontent.com/1of1Adam/dotfiles/main/setup.sh | bash
```

或者克隆后运行：

```bash
git clone https://github.com/1of1Adam/dotfiles.git ~/.dotfiles
cd ~/.dotfiles && ./setup.sh
```

## 📦 包含内容

### 系统配置

| 模块 | 说明 |
|------|------|
| `.macos` | **100+ 项** macOS 系统优化设置 |
| `setup.sh` | 一键配置脚本 |
| `brew.sh` | Homebrew 安装脚本 |

### Shell 配置

| 文件 | 说明 |
|------|------|
| `.aliases` | 命令别名 (git, docker, 现代 CLI 工具等) |
| `.functions` | Shell 函数 (extract, server, mkd 等) |
| `zshrc` | Zsh 配置 (可选) |

### 应用和工具

<details>
<summary><b>CLI 工具</b></summary>

- **现代替代品**: eza (ls), bat (cat), fd (find), ripgrep (grep), fzf, zoxide (cd), dust (du), duf (df), procs (ps), htop (top)
- **开发工具**: git, gh, lazygit, delta, node, pnpm, python, go, rust
- **实用工具**: jq, yq, httpie, tldr, tmux, neovim
- **Shell 美化**: starship, atuin

</details>

<details>
<summary><b>GUI 应用</b></summary>

- **浏览器**: Google Chrome, Arc
- **开发**: VS Code, iTerm2, Docker, Postman
- **效率**: Raycast, Rectangle, HiddenBar
- **其他**: IINA, Notion, Telegram, Discord
- **输入法**: Rime 鼠须管 + 雾凇拼音

</details>

<details>
<summary><b>Nerd 字体</b></summary>

- Fira Code Nerd Font
- JetBrains Mono Nerd Font
- Hack Nerd Font
- Meslo LG Nerd Font

</details>

## 🔧 macOS 设置亮点

`.macos` 文件包含 100+ 项精选设置：

```bash
# 运行 macOS 设置
./.macos
```

<details>
<summary><b>设置详情</b></summary>

**UI/UX**
- 禁用透明效果（提升性能）
- 加快窗口动画速度
- 展开保存/打印对话框
- 禁用智能引号、自动大写、自动纠错

**Finder**
- 显示隐藏文件和扩展名
- 显示路径栏和状态栏
- 禁用 .DS_Store 生成
- 列表视图为默认

**Dock**
- 自动隐藏 + 加速动画
- 隐藏"最近使用的应用"
- 放大效果

**键盘**
- 超快重复速度
- 启用按键重复（禁用长按菜单）
- Tab 切换对话框按钮

**Safari**
- 启用开发者菜单
- 显示完整 URL
- 阻止自动打开下载

</details>

## 📁 目录结构

```
dotfiles/
├── setup.sh          # 一键配置入口
├── brew.sh           # Homebrew 安装脚本
├── .macos            # macOS 系统设置
├── .aliases          # 命令别名
├── .functions        # Shell 函数
├── zshrc             # Zsh 配置 (可选)
└── rime/             # Rime 输入法配置 (雾凇拼音)
```

## 🎯 单独使用

```bash
# 只应用 macOS 设置
./.macos

# 只安装 Homebrew 工具
./brew.sh

# 只加载别名 (添加到 .zshrc)
source ~/.aliases
source ~/.functions
```

## ⚙️ 自定义

1. Fork 这个仓库
2. 修改 `brew.sh` 中的应用列表
3. 修改 `.macos` 中的系统设置
4. 修改 `.aliases` 和 `.functions`
5. 更新 `setup.sh` 中的 GitHub 用户名

## 📝 致谢

- [mathiasbynens/dotfiles](https://github.com/mathiasbynens/dotfiles) - macOS 设置灵感来源
- [iDvel/rime-ice](https://github.com/iDvel/rime-ice) - 雾凇拼音

## ⚠️ 注意事项

- 移除登录密码后，Passkey 功能将不可用
- sudo 免密码配置需要管理员权限
- 部分设置需要重启或注销才能生效
- 建议在安全的环境下使用这些配置
