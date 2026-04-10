# singbox-sync

这是这套 NixOS 配置里 `sing-box` 的生成层。

设计目标只有两个：

- 把稳定不常变的基础配置和订阅节点拆开
- 让 NixOS systemd 服务可以直接消费生成结果

## 文件说明

- `base.json`：稳定基础配置，平时很少改
- `subscription.env.example`：真实私密文件 `subscription.env` 的模板
- `sync_subscription.py`：订阅转换包装脚本，负责把订阅转成 sing-box 的 `outbounds`
- `update-subscription.sh`：本地预览生成脚本，会写 `generated/config.json`
- `generated/config.json`：生成产物，故意不纳入 git

## NixOS 主路径

在这套仓库里，生产路径不是手动脚本，而是：

1. `systemd` 读取 `/etc/sing-box/subscription.env`
2. 调用 Nix 打包好的 `sing-box-subscribe`
3. 生成新配置
4. 先执行 `sing-box check`
5. 成功后替换 `/var/lib/sing-box/config.json`
6. 自动重启 `sing-box`

所以你在新机上真正要准备的只有本地 secret 文件：

```bash
sudo install -d -m 0750 /etc/sing-box
sudo install -m 0640 subscription.env.example /etc/sing-box/subscription.env
sudoedit /etc/sing-box/subscription.env
```

## 本地预览

如果你只想手动预览当前订阅会生成什么配置，可以在用户会话里运行：

```bash
cd "$HOME/dotfiles/scripts/singbox-sync"
./update-subscription.sh
```

如果只是临时测试某个订阅链接，不想改 `subscription.env`，可以直接传 URL：

```bash
./update-subscription.sh 'https://example.com/subscription?token=...'
```

这个脚本会做这些事：

- 读取 `base.json`
- 下载或读取订阅内容
- 调用 `sing-box-subscribe` 转换节点
- 过滤掉诸如 `剩余流量`、`官网`、`套餐到期`、`127.0.0.1:1234` 这类伪节点或占位项
- 追加 `auto`（`urltest`）和 `proxy`（`selector`）
- 写出 `generated/config.json`
- 执行 `sing-box check`

## Selector 规则

生成后的配置里包含：
- `auto`：`type: urltest`
- `proxy`：`type: selector`

当前默认策略是：
- `selector.default = 过滤伪节点后的第一个真实节点`
- `auto` 会出现在 selector 里，但它不是默认值

这样设计的原因：
- 固定默认节点更符合“出口 IP 尽量稳定”的目标
- `auto` 适合拿来做备用路径或临时测速

如果你以后想改默认策略，直接编辑 `sync_subscription.py` 里的 `build_final_config()` 即可。

## NixOS 说明

这套目录仍然可以手动预览，但生产环境不再使用命令式安装脚本。
真正在线上生效的是 NixOS 里定义的 `sing-box-sync.service` 和 `sing-box.service`。
