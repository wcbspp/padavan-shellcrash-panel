# 部署指南

## 先准备原生环境

使用 [ShellCrash 官方项目](https://github.com/juewuy/ShellCrash) 安装 1.9.4，确认在目标路由器上能够正常运行 sing-box。固定目录为 `/etc/storage/ShellCrash`。本包覆盖部分内部脚本，因此不要把框架升级到其他版本后直接继续使用。

关闭旧 SSR 的运行开关，保留其插件和配置。需要已有国内 IPv4 表，时间同步正常，足够 RAM 和剩余 Storage。安装器要求 curl、iptables、ipset、bzip2、sha256sum、mtd_write、mount、stat、awk、tar、base64 和 crontab。

既有 `task/bfstart`、`task/afstart` 非空时安装器拒绝覆盖；已有本项目挂载时也拒绝重新安装。首版没有自动升级器，需要在备份后人工合并或恢复原生环境重新安装。原生开机脚本应使用带 `#ShellCrash初始化脚本` 标记的标准条目；自定义、无标记的启动命令须人工处理，避免并行启动。

## 私有输入

在电脑上准备只包含自己的代理节点的 sing-box JSON。`tools/prepare_profile.py` 读取顶层 `outbounds` 或节点数组，保留节点参数，创建地区选择器和固定管理组 `proxy-main`。不要将私人 JSON 放进本仓库。

从路由器下载 `/etc/storage/chinadns/chnroute.txt`。生成参数见 README；生成器以权限 600 保存配置与随机密钥。它拒绝重复节点名、链式 detour 和不合法网段；不是任意旧版配置的迁移工具。运行时最终由 mini 内核校验协议与字段。

将发布包下载后核对 SHA256SUMS，在路由器 `/tmp` 解压。用 `scp` 上传私有配置、密钥，执行预检与安装。路由器管理员 SSH 权限用于安装；页面继续使用 Padavan 原登录认证。不要把 API 端口 9999 或后台管理端口映射到公网。

## 下载优先级

程序放在 `/tmp/ShellCrash`，配置放在 `/etc/storage/ShellCrash`。每次重启需下载程序，公网下载必须能直连；程序 SHA256 不匹配就拒绝启动。启动后删除压缩缓存，减轻 RAM 压力。下载失败仍保留配置；普通路由应继续可用，但代理不可用。

如有自己的服务器，可在 `configs/core_mirrors.list` 按行添加程序 URL，最上方先尝试。文件必须与 `configs/core-installed.info` 的 SHA256 对应。默认空表走 ShellCrash 上游固定版本公共源。例子见 `examples/core_mirrors.list.example`。

国内域名规则镜像写在 `configs/panel.conf` 的 `PANEL_CN_MIRROR`；它也需要匹配脚本的固定 SHA256。普通配置文件是被 shell source 的可信管理员配置，不接受不可信用户编辑。

内核更新按钮读取 ShellCrash 配置的 `custcorelink` 或框架适配源。固定版本源没有更新时不会下载另一份程序。要更新到新版本，先确认 ShellCrash 源、内核格式和体积限制；不保证所有最新 sing-box 都适合 128 MB 设备。

## 配置和规则

网页订阅更新使用原始节点名字；节点选择按分钟保存，页面显示保存状态。订阅、DNS 名单、规则和内核元数据会保存到 Storage。程序下载不覆盖这些配置。

国内 IPv4 规则由本项目管理动作下载和校验，国内域名规则使用固定的 SRS 文件；不是由 Clash 自动管理数据库。旧 SSR 关闭时其规则更新脚本会被 RAM 包装器拦截，改用新面板更新。

Mix 表示国内域名返回真实地址，其他 A 查询返回 Fake IP；例外名单返回真实地址，但**返回真实 IP 不代表直连**，流量仍按路由规则处理。例外名单含 OpenClash 风格 `+.`、`*.` 等域名规则；用网页保存会验证格式。不支持直接引用 geosite 语法。AAAA 拒绝、普通 UDP 直连是此适配包的明确限制。
