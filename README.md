# Padavan ShellCrash Panel

把 ShellCrash 接进 Padavan 后台：切节点、更新订阅、改 DNS、看日志，都可以在网页里操作。

适用于 **K2P / MT7621 + Padavan + ShellCrash 1.9.4**，使用 sing-box mini 1.12.13。需要先装好 ShellCrash；本项目安装的是管理面板和配套脚本。

## 安装

### 1. 下载并解压到电脑

[下载 v0.1.1 安装包](https://github.com/wcbspp/padavan-shellcrash-panel/releases/download/v0.1.1/padavan-shellcrash-panel-0.1.1.zip)。电脑需要 Python 3.9 或更新版本、SSH；macOS / Linux 可以直接运行，Windows 使用 WSL。

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
| 订阅链接 | AnyTLS 或 sing-box JSON 订阅；直接回车则沿用现有节点 |

安装助手会自动生成配置、上传文件、检查环境、把安装前备份下载到电脑，再安装并检查服务。第一次 SSH 连接时，终端可能会询问是否信任这台路由器。

### 3. 打开路由器后台

登录后点击 **高级设置 → ShellCrash**。如果没看到菜单，刷新浏览器缓存。安装时输入的订阅链接会保存在面板中，以后点「订阅 → 更新」即可。

安装前备份保存在你运行命令的文件夹，文件名以 `shellcrash-before-` 开头。请留好，恢复方法见 [备份与卸载](docs/RECOVERY.md)。

遇到错误时看终端最后一条提示；常见问题见 [安装说明](docs/DEPLOYMENT.md)。

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
- 查看内存趋势、异常发生时间和诊断记录；低内存时暂停耗资源的管理操作。

程序在 RAM 中运行，重启会重新下载；节点、订阅和 DNS 设置保存在路由器 Storage 中，不会随程序下载而重置。

**自定义镜像可选。** 不配置时使用公共下载源；配置后按「自定义镜像 → 公共源」的顺序直连下载，启动下载不依赖代理。公共源直连不稳定时，可以把对应内核压缩包放到自己的服务器。镜像文件必须与当前版本的校验值一致，更新内核后也要同步镜像。设置方法见 [自定义下载镜像](docs/MIRRORS.md)。

普通 UDP 直连，AAAA 查询拒绝。具体行为见 [运行方式与限制](docs/ARCHITECTURE.md)。

## 版本与兼容性

目前是实验版。原部署已在 K2P、Padavan `4.4.198.9-100_20220804` 上验证；整理后的安装助手通过模拟安装测试，还没有在另一台干净路由器上完整验证。其他 Padavan 分支不保证兼容。

订阅支持 AnyTLS 链接、Base64 和 sing-box JSON；不支持直接导入 Clash YAML 或其他协议的 URI。JSON 中的协议还需当前 mini 内核支持。

已有自定义启动钩子时，安装助手会停止并提示，不会覆盖。已经装过本面板的路由器也会拒绝重复安装；本版本没有自动升级功能。需要手动部署时看 [手动安装](docs/MANUAL_INSTALL.md)。

## 开发

```sh
python3 tests/test_project.py
python3 tools/build_release.py
```

可选的 GitHub Actions 配置在 `docs/ci-example.yml`。

## 许可

GPL-3.0-only，基于 [ShellCrash](https://github.com/juewuy/ShellCrash)。版权和图标来源见 [NOTICE](NOTICE.md)。发布包不含私人订阅、密码、ZeroTier 身份或程序二进制。
