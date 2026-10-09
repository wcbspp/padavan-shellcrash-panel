# 备份与恢复

## 安装前

安装器备份 `/etc/storage/ShellCrash` 和 `/etc/storage/started_script.sh` 到 `/tmp/padavan-panel-before-install.tar.gz`。这是**私人备份**，包含节点与密钥，重启会丢失。通过 SCP 下载到电脑或自己的备份服务器，限制权限，不上传到 GitHub 或 Release。

建议另备份完整 `/etc/storage`、固件版本、NVRAM 配置以及 ZeroTier 身份。备份文件存入服务器不等于自动恢复；ZeroTier 身份也不要与开源安装包混合。

## 卸载

将同一台路由器的安装前备份上传后，在维护时间执行：

```sh
sh uninstall.sh /tmp/padavan-panel-before-install.tar.gz
```

脚本停止当前服务，恢复安装前 ShellCrash 目录和开机脚本并保存 Storage。随后手动重启路由器，移除 RAM 中的网页及旧插件保护覆盖，再验证原服务。不要用其他设备的备份覆盖本机，也不要对不可信归档执行恢复。

## 启动失败

通过 LAN 管理地址或 SSH 检查 `/tmp/ShellCrash/debug.log`、`/tmp/ShellCrash/core.log`、系统日志和 `/tmp/sc-admin`。下载失败先检查路由器时间、直连源和 SHA256，避免关闭 TLS 校验绕过问题。程序损坏不会修改持久配置。

如果网页菜单没有出现，确认 `/www/state.js`、原 Padavan 认证和 `/custom` 映射可用；存在已有 `/opt` 时本项目不会覆盖其内容。其他固件分支没有本版本接口时，需要修改适配脚本。

配置校验失败先保留原配置；网页更新会尝试回滚。Flash 保存失败必须先备份后处理，不要立即断电。安装事务退出失败也会尝试恢复，但 shell 被强杀、断电或 Flash 写入失败不在自动回滚保证内。
