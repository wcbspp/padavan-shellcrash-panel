# 自定义下载镜像

K2P 的程序放在 RAM 里，路由器断电后就没有了。每次开机需要下载内核压缩包和国内域名规则，再启动代理；订阅、节点选择和 DNS 设置保存在 Storage 中。

自定义镜像不是必填。公共下载源能直连时，可以直接用默认设置。直连不稳定时，把文件放到自己的服务器，开机先从那里下载。

## 下载顺序

1. 按 `core_mirrors.list` 从上到下尝试自定义内核镜像。
2. 下载失败或 SHA256 不匹配，尝试 ShellCrash 公共源。
3. 国内域名规则优先使用 `PANEL_CN_MIRROR`，失败或校验不符再尝试公共规则源。

这些启动下载都走直连，不依赖已经运行的代理。镜像地址应在代理启动前就能访问，不能依赖这台路由器的代理才能打开。

如果所有来源都失败，代理启动不了，但保存的配置还在。不要用关闭校验或随便换一个程序文件的办法跳过错误。

## 服务器上放什么

只需一个能直连下载文件的 HTTP / HTTPS 静态地址，例如：

```text
https://downloads.example.com/singbox-mini-1.12.13-mipsle.tar.gz
https://downloads.example.com/cn.srs
```

内核压缩包从路由器 `configs/core-installed.info` 的 `url` 下载，核对其中的 `sha256`。必须是同一份文件；同版本的其他构建、解压后重新打包的文件，校验值也可能不同。

`cn.srs` 是可选规则镜像，来源和 SHA256 记录在 `starts/panel_bfstart.sh`。只配内核镜像时，国内域名规则仍从公共源下载；如果希望开机完全优先走自己的服务器，这个文件也要配置。

镜像不需要放订阅、密码、节点配置或备份。配置备份另外保存，不能放到公开下载目录里。

## 路由器上怎么设置

目前网页没有镜像设置入口，需要首次通过 SSH 编辑。以下示例地址要换成自己的实际下载地址。

### 内核镜像

编辑 `/etc/storage/ShellCrash/configs/core_mirrors.list`，每行一个地址：

```text
https://downloads.example.com/singbox-mini-1.12.13-mipsle.tar.gz
```

可填多个镜像，优先的放第一行；不填就走公共源。内核文件名可以自定义，但更新版本后要检查地址和文件是否对应。

### 国内域名规则镜像

编辑 `/etc/storage/ShellCrash/configs/panel.conf`，加入：

```sh
PANEL_CN_MIRROR='https://downloads.example.com/cn.srs'
```

### 保存到 Flash

改完后在路由器 SSH 中执行：

```sh
sh /etc/storage/ShellCrash/starts/save_storage.sh
```

看到保存成功或 Storage 未变化的提示后再重启，否则编辑可能没有固化。

## 更新内核后

网页的内核更新按钮仍使用 ShellCrash 配置的更新源，自定义镜像负责开机下载。更新成功后，把新版本对应的压缩包同步到镜像服务器，并确认镜像地址正确。

如果镜像仍是旧文件，开机时会因校验不符跳过它，改走公共源，不会偷偷启动旧内核。
