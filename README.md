# Padavan ShellCrash Panel

把 ShellCrash 接进 Padavan 后台：切节点、更新订阅、改 DNS、看日志，都可以在网页里操作。

适用于 **K2P / MT7621 + Padavan**，使用 ShellCrash 1.9.4 和 sing-box mini 1.12.13。安装包已包含 ShellCrash 基础脚本；新设备会自动安装，已有安装会先检查版本。

## 安装

需要配套底层固件时，见 [K2P 16 MB 固件下载与验证](docs/FIRMWARE.md)。四个版本分别提供，包含本机正在使用的完整版和 K2P-USB 版；本批仅适用于 16 MB 闪存。

### 1. 下载并解压到电脑

[下载 v1.1.0 安装包](https://github.com/wcbspp/padavan-shellcrash-panel/releases/download/v1.1.0/padavan-shellcrash-panel-1.1.0.zip)。电脑需要 Python 3.9 或更新版本、SSH；macOS / Linux 可以直接运行，Windows 使用 WSL。

路由器先开启 SSH，在原「科学上网」页面关闭 SSR 的运行开关。电脑连到这台路由器的局域网。

### 2. 在解压后的文件夹里打开终端

只需执行这一条：

```sh
python3 tools/deploy.py
```

按提示填写：

| 提示 | 填什么 |
| --- | --- |
| 路由器地址 | 自己的 LAN 网关，例如 `192.168.1.1` |
| SSH 用户名 | 默认 `admin`，按实际情况修改 |
| SSH 端口 | 默认 `22`，没改过就直接回车 |
| SSH 密码 | 路由器管理员密码；输入时不会显示 |
| 订阅链接 | 首次安装必填；已有节点时直接回车即可沿用 |

安装助手会自动生成配置、上传文件、检查环境、把安装前备份下载到电脑，再安装 ShellCrash、面板和开机启动脚本，最后检查服务。第一次 SSH 连接时，终端可能会询问是否信任这台路由器。

### 3. 打开路由器后台

登录后点击 **高级设置 → ShellCrash**。如果没看到菜单，刷新浏览器缓存。安装时输入的订阅链接会保存在面板中，以后点「配置 → 更新订阅」即可。

安装前备份保存在你运行命令的文件夹，文件名以 `shellcrash-before-` 开头。请留好，恢复方法见 [备份与卸载](docs/RECOVERY.md)。

遇到错误时看终端最后一条提示；常见问题见 [安装说明](docs/DEPLOYMENT.md)。

## 包里有什么

- 官方 ShellCrash 1.9.4 基础脚本与原始压缩包。
- 管理面板、后端脚本、开机启动和异常恢复脚本。
- 电脑安装助手、备份和卸载工具。

如果只需要基础包，可以下载 [ShellCrash 1.9.4 原包](https://github.com/wcbspp/padavan-shellcrash-panel/releases/download/v1.1.0/ShellCrash-1.9.4.tar.gz)。它来自 [官方 1.9.4 发布](https://github.com/juewuy/ShellCrash/releases/tag/1.9.4)，源码、来源与校验值保留在 `vendor/`。

sing-box 内核不打进基础包，安装和重启时按下载源获取；自定义镜像设置见下方说明。

## 界面

完整 Padavan 后台，左侧保留「科学上网」，新增「ShellCrash」。截图中的节点、延迟和运行状态是演示数据。

![Padavan 后台中的 ShellCrash 节点管理](docs/assets/padavan-nodes.png)

![Padavan 后台中的网站检测](docs/assets/padavan-checks.png)

## 功能

- 按地区查看具体节点、切换节点、自动测速并保存选择。
- 检测百度、腾讯、Google、YouTube 等网站是否能访问。
- 更新订阅，启动、停止或重启服务。
- 修改 DNS 模式、Fake IP 例外名单，更新国内 IP 规则。
- 查看和清空日志，检查与更新内核。
- 在“监控”页查看可用内存、趋势与异常时间，刷新状态或安全清理临时文件；低内存时暂停耗资源的管理操作。

程序在 RAM 中运行，重启会重新下载；节点、订阅和 DNS 设置保存在路由器 Storage 中，不会随程序下载而重置。

**自定义镜像可选。** 不配置时使用公共下载源；配置后按「自定义镜像 → 公共源」的顺序直连下载，启动下载不依赖代理。公共源直连不稳定时，可以把对应内核压缩包放到自己的服务器。镜像文件必须与当前版本的校验值一致，更新内核后也要同步镜像。设置方法见 [自定义下载镜像](docs/MIRRORS.md)。

普通 UDP 直连，AAAA 查询拒绝。具体行为见 [运行方式与限制](docs/ARCHITECTURE.md)。

## 版本与兼容性

目前是实验版。原部署已在 K2P、Padavan `4.4.198.9-100_20220804` 上验证；整理后的安装助手已通过首次安装、失败回滚和恢复配置的模拟测试，还没有在另一台干净路由器上完整验证。其他 Padavan 分支不保证兼容。

订阅支持 AnyTLS 链接、Base64 和 sing-box JSON；不支持直接导入 Clash YAML 或其他协议的 URI。JSON 中的协议还需当前 mini 内核支持。

已有自定义启动钩子时，安装助手会停止并提示，不会覆盖。已经装过本面板的路由器也会拒绝重复安装；本版本没有自动升级功能。需要手动部署时看 [手动安装](docs/MANUAL_INSTALL.md)。

## 开发

```sh
python3 tests/test_project.py
python3 tests/test_mirror.py
python3 tests/test_rules_paths.py
python3 tools/build_release.py
```

可选的 GitHub Actions 配置在 `docs/ci-example.yml`。

## 许可

GPL-3.0-only，基于 [ShellCrash](https://github.com/juewuy/ShellCrash)。版权和图标来源见 [NOTICE](NOTICE.md)。发布包不含私人订阅、密码、ZeroTier 身份或 sing-box 内核二进制。

自定义镜像可在“订阅”页维护，显示公共适配源与镜像版本；配置专用 SSH 上传密钥后，内核和 IP 规则更新会自动同步镜像。见 [镜像配置](docs/MIRRORS.md)。

![订阅、内核和镜像设置（节点与地址为示例）](docs/assets/padavan-subscription.png)

国内 IP 默认表随安装包提供，不依赖旧 SSR 的 chinadns 目录。首次导入已有规则，此后使用 ShellCrash 自己的持久化文件；前台可手动更新，失败保留原表。

版本变更见 [CHANGELOG.md](CHANGELOG.md)

## 1.1.0 更新

节点顺序采样三次，显示成功样本的最短时间；首个请求可能包含握手。配置页可检查和更新官方 stable 正式版 ShellCrash 工具。工具更新保留本项目适配及运行配置，不重启其他服务；同版不替换，上游适配依赖发生变化时拒绝覆盖。

开机只恢复已安装内核版本，不查询新版本。K2P 默认内核包位于内存，重启需下载；有可用外部存储时可配置持久化 archive。配置仍保存在 Storage。镜像上传失败单独提示待同步，可手动重试，已验证的内核不会仅因同步失败而撤回。

验证与限制见[变更记录](CHANGELOG.md)。当前正式工具仍为 1.9.4release，新正式版替换及失败回退通过离线夹具验证。
