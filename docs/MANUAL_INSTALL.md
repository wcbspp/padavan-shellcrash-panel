# 手动安装

这是不用安装助手时的操作步骤。电脑和路由器上的命令分开列出；示例网关 `192.168.1.1`、用户名 `admin` 均需按实际情况修改。

前提与 [安装说明](DEPLOYMENT.md) 相同。先停止旧 SSR，准备好可用的 sing-box 节点 JSON，命名为 `nodes.json`，放在解压后的安装包文件夹。

## 1. 在电脑上取回国内 IP 表

以下命令在解压后的文件夹执行：

```sh
scp -O admin@192.168.1.1:/etc/storage/chinadns/chnroute.txt ./chnroute.txt
```

## 2. 在电脑上生成配置

```sh
python3 tools/prepare_profile.py --input nodes.json --output config.private.json \
  --lan-ip 192.168.1.1 --secret-file panel-secret.private --cn-list chnroute.txt
```

这会生成配置和随机密钥。不要把这两个文件上传到公开仓库。

## 3. 从电脑上传到路由器

把下载的 `.tar.gz` 放在当前文件夹，然后执行：

```sh
scp -O padavan-shellcrash-panel-0.1.1.tar.gz config.private.json panel-secret.private admin@192.168.1.1:/tmp/
ssh admin@192.168.1.1
```

## 4. 在路由器上安装

SSH 登录后的命令：

```sh
cd /tmp
tar -xzf padavan-shellcrash-panel-0.1.1.tar.gz
cd padavan-shellcrash-panel-0.1.1
sh install.sh --check --profile /tmp/config.private.json
sh install.sh --install --profile /tmp/config.private.json --secret-file /tmp/panel-secret.private
```

检查失败时先处理提示，不要跳过。成功后登录路由器后台，打开「高级设置 → ShellCrash」。

## 5. 在电脑上保存安装前备份

另开一个电脑终端：

```sh
scp -O admin@192.168.1.1:/tmp/padavan-panel-before-install.tar.gz ./
```

然后在路由器终端删除临时输入：

```sh
rm -f /tmp/config.private.json /tmp/panel-secret.private
```

备份保存在路由器 `/tmp` 时，重启就会丢失。恢复步骤见 [备份与卸载](RECOVERY.md)。
