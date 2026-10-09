# 自定义镜像

打开路由器后台 → 高级设置 → ShellCrash → 订阅 → 自定义镜像。

- **镜像目录地址**：例如 `https://downloads.example.com/shellcrash-core/objects`，不要填单个文件地址。
- **SSH 上传目标**：例如 `scmirror@server.example.com:22`。留空时只使用下载镜像，不自动上传。
- **保存地址**：保存到路由器 Storage，重启继续使用。不会重启代理。
- **同步当前文件**：把当前内核、国内 IP 表和固定版本域名库上传，并从下载地址读回校验。
- **源版本**：显示运行内核、ShellCrash 公共适配源、镜像源的内核版本。点击内核“检查更新”刷新两处源信息。即使版本号相同，文件校验值不同也显示不一致。

## 下载与更新

开机时，内核和 `cn.srs` 优先从镜像直连下载；失败再尝试公共源。内核按已保存的 SHA256 下载，无法用旧文件替换新版本。节点、DNS 设置和国内 IP 表都保存在 Storage，其中 IP 表使用 `ShellCrash/configs/cn_ip.txt`；重启不重新下载配置或 IP 表。

“更新内核”向 ShellCrash 已配置的适配源检查最新版本，程序包优先从镜像下载；没有对应文件时从原源下载。新程序通过版本、配置校验后，先上传镜像并验证下载，再保存安装记录。上传失败则回退原内核。

“更新国内 IP 规则”从原来的 `ispip.clang.cn` 获取最新表，校验后先同步镜像，再应用并保存。不能只向镜像检查最新 IP 表，否则服务器未更新时会一直停在旧规则。`cn.srs` 仍使用已测试的固定版本；此按钮不更新域名库。

只配置下载地址而不填上传目标时，更新可正常执行，但需要自行维护服务器文件。界面会显示“上传未配置”。首次部署上传密钥后，建议先点击“同步当前文件”。

镜像上传走已有 SSH 端口，不新增监听服务，不需要在页面保存服务器密码。订阅、节点密码、完整配置和备份不会上传到公开镜像目录。

## 文件布局

接收器使用内容校验值命名，旧文件不会冒充新版：

```text
core-<SHA256>.tar.gz          内核程序包
blob-<Git blob SHA1>.tar.gz   同一个程序包的硬链接，供适配源检查后下载
cn-<SHA256>.srs              固定国内域名库
rules-<SHA256>.txt           国内 IPv4 表
info-<SHA256>.txt            内核版本、架构与校验信息
core-info.txt               最近成功同步的内核信息
```

`core-info.txt` 用于界面显示。启动始终使用路由器已保存的版本和 SHA256，不依赖这份可变信息选择版本。

## 首次配置上传服务

服务器需要 Python 3.6+ 和已有的 HTTP/HTTPS 文件服务。接收器不启动常驻进程。

1. 复制项目的 `tools/mirror_receive.py` 到服务器 `/usr/local/libexec/shellcrash-mirror-receive.py`，由 root 所有，普通用户不可修改。
2. 创建专用用户 `scmirror`，给它一个公开下载目录的写权限；其他服务器目录不授予写权限。
3. 在路由器生成密钥：

```sh
umask 077
dropbearkey -t rsa -s 2048 -f /etc/storage/ShellCrash/configs/mirror_key
dropbearkey -y -f /etc/storage/ShellCrash/configs/mirror_key
```

4. 将输出的 `ssh-rsa …` 公钥加入服务器该用户的 `authorized_keys`。这一行必须有以下前缀，后面接公钥：

```text
command="SC_MIRROR_ROOT=/srv/shellcrash-mirror /usr/bin/python3 /usr/local/libexec/shellcrash-mirror-receive.py",no-port-forwarding,no-agent-forwarding,no-X11-forwarding,no-pty ssh-rsa …
```

5. 通过可信的服务器管理连接取得 SSH 主机公钥，在路由器 `/etc/storage/ShellCrash/configs/mirror_known_hosts` 保存一行 `服务器域名 ssh-ed25519 公钥内容`。Dropbear 使用不带端口的主机名；不要附注释。不能关闭主机指纹检查。若系统全局禁用公钥认证，只为 `scmirror` 启用；不要修改其他用户的认证设置。
6. 用现有网站服务公开上述文件，禁止上传、目录索引和以点开头的文件。接收器未完成的文件以 `.incoming-` 开头，不应被下载。
7. 在面板保存镜像目录和 SSH 目标，再点击“同步当前文件”。文件会经 SSH 上传、从公开下载地址校验，成功后保存 Storage。

HTTP 镜像不传输密码，但下载必须匹配 SHA256。更换服务器时同时维护下载地址、SSH 目标和主机指纹；页面不会自动信任新的服务器。

## 兼容旧配置

已有 `configs/core_mirrors.list` 和 `PANEL_CN_MIRROR` 继续作为备用下载地址。面板维护的新目录优先于这些旧地址。下载目录留空不会删除旧地址；若希望完全使用公共源，应同时清理旧配置。

内核和域名库放在 RAM，断电后重新下载；ShellCrash 本体、面板、配置保存在 Storage。镜像不是配置备份，私有备份另存受保护目录。

## 国内 IP 表的持久化与路径

安装包附带 `examples/cn_ip.default.txt`，共 4507 条 IPv4 网段，来自 ShellCrash 1.9.4 官方原包。来源和 SHA256 在 `examples/cn_ip.default.info`。

首次启动按以下顺序查找可用表并导入 ShellCrash 自己的 `configs/cn_ip.txt`：指定的 `PANEL_CN_IP_FILE`、旧插件 `/etc/storage/chinadns/chnroute.txt`、ShellCrash 原来的 `cn_ip.txt`、内置默认表。缺失的路径和校验不通过的旧表跳过，不要求创建旧插件目录。

如果当前规则在其他位置，可在 `configs/panel.conf` 设置 `PANEL_CN_IP_FILE='/你的路径/chnroute.txt'`，用于首次导入。指定路径不存在时仍回退内置表。已有的有效 `configs/cn_ip.txt` 始终优先，避免重启覆盖手动更新。

此后前台“更新国内 IP 规则”只维护 ShellCrash 自己的持久化表，并同步内核、防火墙和已配置的镜像。更新失败保留旧表；规则相同不重启。`rules.meta` 缺失时自动补齐，不会因为少了更新记录文件而失败。

这解决国内规则的路径依赖；安装器仍针对文档中列出的 K2P/Padavan 环境，不表示支持所有路由器固件。
