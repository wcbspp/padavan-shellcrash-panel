# K2P 16 MB 配套固件

[下载固件及校验文件](https://github.com/wcbspp/padavan-shellcrash-panel/releases/tag/firmware-k2p-16m-4.4.198.9-100)

本批为提供者保存的四份 2022 年 Padavan 原固件，适用范围限定为 **16 MB 闪存的 K2P**。这里的 16 MB 是闪存容量，不是内存容量；本机读取到的闪存大小为 16 MiB（16777216 字节）。32 MB 改版不在本批适用范围内。

## 选择文件

| 发布文件 | 原文件标注 | 编译日期（UTC） | 大小（MiB） | 验证情况 |
|---|---|---|---:|---|
| K2P-16M-4.4.198.9-100-trojan-v2ray-xray-zerotier.trx | trojan + v2ray + xray + ZeroTier | 2022-08-04 | 14.94 | 与本机固件逐字节一致，当前面板运行于此版本 |
| K2P-16M-4.4.198.9-100-trojan-zerotier.trx | trojan + ZeroTier | 2022-07-29 | 10.69 | 文件静态校验通过，未刷机验证 |
| K2P-16M-4.4.198.9-100-clean.trx | 纯净无插件 | 2022-06-30 | 7.35 | 文件静态校验通过，未刷机验证 |
| K2P-USB-16M-4.4.198.9-100-trojan-zerotier.trx | USB / trojan + ZeroTier | 2022-07-30 | 14.81 | 文件静态校验通过，未刷机验证；产品标识为 K2P-USB |

USB 版具有独立的 K2P-USB 产品标识，应对应 USB 改造硬件使用；普通 K2P 选择 K2P 文件。Padavan 上游也分别定义 [K2P-USB 模板](https://github.com/hanwckf/rt-n56u/blob/master/trunk/configs/templates/K2P-USB.config)与[板级标识](https://github.com/hanwckf/rt-n56u/blob/master/trunk/configs/boards/K2P-USB/board.h)，这些参考不代表本批固件的确切源码来源。

组件栏沿用原文件名，未逐项解包核验组件版本。附件只是将文件名改为便于下载的英文名称，文件内容和 SHA256 保持。

## 核验方法与结果

2026-10-09 读取设备版本与 MTD 分区信息，然后将只读 firmware 分区直接流传到电脑比较。核验没有刷写或重启设备，没有读取 Config、Factory、Storage 或完整 ALL 分区。

- 设备产品标识：K2P；版本：4.4.198.9-100_20220804；内核：4.4.198。
- 闪存：0x01000000；firmware 分区：0x00f30000（15925248 字节）；Storage：0x00080000（512 KiB）。
- 完整版原文件 15666738 字节，与只读 firmware 分区前 15666738 字节完全一致；内核及 SquashFS 数据也一致。
- 四份文件的 uImage 文件长度、头部 CRC32、数据 CRC32 均通过，文件大小均能装入本机 firmware 分区。此结果不等于其他三份已通过启动或面板兼容性测试。
- 逐文件校验值、原名、发布名和验证结果见 [FIRMWARE_MANIFEST.json](FIRMWARE_MANIFEST.json)。附件 SHA256SUMS 可用于下载后的完整性检查。

## 与面板安装的关系

附件提供的是 Padavan 底层固件，ShellCrash 面板需另行安装。订阅链接、账号凭据、ZeroTier 身份等个人配置不随固件提供，由用户在设备上设置，并保存在独立的 Storage 分区。

路由器已运行兼容的 Padavan 固件时，按 [安装步骤](../README.md#安装)部署面板即可。需要恢复或更换底层固件时，可选择对应附件，刷写前先备份设备配置。

这些固件为用户提供的历史版本，文件内容保持不变。原编译者、对应源码版本及编译配置尚未核实；本项目的 GPL-3.0-only 许可不改变固件及其组件原有的许可。
