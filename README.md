# macOS 新电脑一键配置

新电脑开箱后的一键配置脚本。

## 快速使用

```bash
# 下载并运行（需要先登录 GitHub）
curl -fsSL https://raw.githubusercontent.com/peng-xiao-shuai/mac-setup/main/setup.sh | bash
```

## 配置内容

| 功能 | 说明 |
|------|------|
| sudo 免密码 | 在 `/etc/sudoers.d/` 创建免密码规则 |
| 移除登录密码 | 可选，将登录密码设为空 |
| Homebrew | macOS 包管理器 |
| 常用工具 | git, node, pnpm, python, gh, jq, ripgrep, fzf, eza, bat, fd |
| Google Chrome | `brew install --cask google-chrome` |
| Git 配置 | 用户名、邮箱、默认分支 main |
| Claude Code | `curl -fsSL https://claude.ai/install.sh \| bash` |
| OpenAI Codex | `npm i -g @openai/codex` |

## 单独配置 sudo 免密码

```bash
# 手动配置（替换 USERNAME 为你的用户名）
echo "USERNAME ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/USERNAME
sudo chmod 440 /etc/sudoers.d/USERNAME
```

## 单独移除登录密码

```bash
# 将密码改为空（需要输入当前密码）
dscl . -passwd /Users/$(whoami) "当前密码" ""
```

## 注意事项

- 移除登录密码后，Passkey 功能将不可用（Apple 强制要求密码）
- sudo 免密码配置需要管理员权限
- 建议在安全的环境下使用这些配置
