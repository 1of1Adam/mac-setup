# Auto Installer (Downloads: .dmg / .iso*)

一个常驻后台的 LaunchAgent：当 `~/Downloads` 出现新下载且写入完成的磁盘镜像（`.dmg`、`.iso`、以及常见的 `.iso.*` 变体如 `.iso.cdr`）时，自动执行：挂载 -> 安装 -> 打开 -> 卸载 -> 移动到回收站。

## 安装

```bash
bash "$HOME/.dotfiles/auto-installer/install.sh"
```

或（在任意机器上，直接 curl 执行）

```bash
curl -fsSL https://raw.githubusercontent.com/1of1Adam/dotfiles/main/auto-installer/install.sh | bash
```

## 卸载

```bash
bash "$HOME/.dotfiles/auto-installer/uninstall.sh"
```

## 配置

配置文件路径：

- `~/Library/Application Support/AutoInstaller/config.json`

常用配置：

- `openPolicy`: `all` | `primary` | `none`
- `installDir`: 默认 `/Applications`（需要 sudo；若 sudo 失败会记录日志并标记失败）

## 日志

- 主日志：`~/Library/Logs/auto-installer.log`
- launchd stdout/stderr：`~/Library/Logs/auto-installer.launchd.{out,err}.log`

## 安全提示

该工具会自动安装并打开下载目录里的镜像文件，风险很高。请确保你完全理解其行为，并只在可信环境使用。
