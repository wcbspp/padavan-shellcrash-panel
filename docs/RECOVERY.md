# 备份与卸载

## 备份在哪里

通过电脑安装助手部署时，备份会自动下载到运行命令的文件夹，文件名以 `shellcrash-before-` 开头。它包含安装前的 ShellCrash 目录、路由器开机脚本及已有国内 IP 表。首次安装时还会记录原来没有哪些文件。

手动安装时，备份在路由器 `/tmp/padavan-panel-before-install.tar.gz`；需要自己下载到电脑，路由器重启后这份临时文件就没了。

备份里有私人节点和密码，不要上传到公开仓库。它不包含完整固件、NVRAM 或 ZeroTier 身份；这些需要另外备份。

## 恢复安装前的配置

只使用这台路由器自己的安装前备份。

1. 在电脑上，把要恢复的备份复制并重命名为 `before-install.tar.gz`，放到解压后的安装包文件夹。
2. 在该文件夹打开终端，执行下列命令。网关和用户名按实际情况修改：

```sh
scp -O before-install.tar.gz uninstall.sh restore_storage.sh admin@192.168.1.1:/tmp/
ssh admin@192.168.1.1 'sh /tmp/uninstall.sh /tmp/before-install.tar.gz'
```

3. 出现「原始 Storage 已恢复」后，从路由器后台手动重启。重启会移除 RAM 中的网页覆盖，原来的 ShellCrash 配置和开机方式会恢复。如果安装前没装过 ShellCrash，新安装的框架和国内规则文件也会移除。

如果提示保存失败，先保留备份并处理错误，不要立即断电。

## 安装失败怎么办

安装器在新服务启动失败时会尝试恢复原配置。安装助手下载到电脑的备份仍会保留。若自动恢复没成功，按上面的步骤手动恢复。

通过局域网登录路由器，查看 `/tmp/ShellCrash/debug.log`、`/tmp/ShellCrash/core.log`、系统日志和 `/tmp/sc-admin`。下载失败先检查时间同步、源地址和电脑 / 路由器网络；不要通过关闭证书校验来跳过错误。

若断电、强杀安装进程或 Flash 写入失败，自动回滚不一定能完成。恢复配置后再次检查原服务是否正常。
