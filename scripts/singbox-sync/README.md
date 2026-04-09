# singbox-sync

一个给 `sing-box` 用的、尽量简单直接的订阅同步流水线。

它把稳定不常变的基础配置和机场订阅生成的节点配置分开：
- 基础层：`tun`、`dns`、`route`、本地 `clash_api`、日志等
- 生成层：从 Clash 风格订阅转换出来的节点，以及 `selector` 和 `urltest`

这个目录本身**不会**修改当前正在运行的服务。只有你明确执行 `install-generated-config.sh` 时，当前的 `/etc/sing-box/config.json` 才会被替换。

## 文件说明

- `base.json`：稳定基础配置，平时很少改
- `subscription.env.example`：真实私密文件 `subscription.env` 的模板
- `sync_subscription.py`：订阅转换包装脚本，负责把订阅转成 sing-box 的 `outbounds`
- `update-subscription.sh`：拉取订阅、转换节点、过滤伪节点、生成最终配置并执行 `sing-box check`
- `install-generated-config.sh`：可选的手动安装步骤，用来替换 `/etc/sing-box/config.json`
- `generated/config.json`：生成产物，故意不纳入 git

## 一次性准备

1. 先把你的 dotfiles 仓库 clone 下来。
2. 只做一次 converter 准备：

```bash
git clone --depth 1 https://github.com/NiuStar/sing-box-subscribe "$HOME/tools/sing-box-subscribe"
cd "$HOME/tools/sing-box-subscribe"
uv venv .venv
uv pip install --python .venv/bin/python -r requirements.txt
```

说明：
- `update-subscription.sh` 默认会去 `$HOME/tools/sing-box-subscribe` 找 converter
- 如果你放在别处，可以用 `CONVERTER_DIR=/some/path` 覆盖
- 脚本会自动打上一个很小的本地补丁，用来处理 `smux.enabled=true` 但缺少 `smux.protocol` 的订阅

3. 在本地创建真实的私密配置文件，但不要提交进 git：

```bash
cd "$HOME/dotfiles/scripts/singbox-sync"
cp subscription.env.example subscription.env
$EDITOR subscription.env
```

## 日常用法

用 `subscription.env` 里的默认订阅生成一份候选配置：

```bash
cd "$HOME/dotfiles/scripts/singbox-sync"
./update-subscription.sh
```

如果只是临时测试某个订阅链接，不想改 `subscription.env`，可以直接传 URL：

```bash
./update-subscription.sh 'https://example.com/subscription?token=...'
```

更新脚本实际会做这些事：
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

## 安全切换

第一次切换时，建议按这个顺序做：

1. 先把当前单节点配置备份到 `/etc/sing-box` 目录外：

```bash
sudo cp /etc/sing-box/config.json /root/sing-box-config.single-sg1.json
```

2. 只有当你真的想切过去时，才安装生成好的候选配置：

```bash
cd "$HOME/dotfiles/scripts/singbox-sync"
sudo ./install-generated-config.sh
```

3. 如果之后要切回原来的单节点配置：

```bash
sudo install -m 640 -o root -g sing-box /root/sing-box-config.single-sg1.json /etc/sing-box/config.json
sudo rm -f /var/lib/sing-box/cache.db
sudo systemctl restart sing-box
```

注意：
- 不要把额外的 `.json` 备份文件放在 `/etc/sing-box` 里
- 你当前的服务是用 `sing-box -C /etc/sing-box` 启动的，这个目录里的配置文件可能会被一起加载

## NixOS 说明

这套生成器和发行版关系不大。在 NixOS 上，生成步骤保持不变：

```bash
cd "$HOME/dotfiles/scripts/singbox-sync"
./update-subscription.sh
```

真正不同的只有最后安装这一步：
- 命令式用法：还是把生成文件复制到 `/etc/sing-box/config.json`
- 声明式用法：保留这个目录作为生成器，等你准备好时，再把 `generated/config.json` 接进你的 Nix 配置

## 这台机器当前状态

当前正在运行的服务是刻意保持不变的。
测试过的“订阅版候选配置”在这里：
- `~/dotfiles/scripts/singbox-sync/generated/config.json`

除非你主动执行安装脚本，否则线上仍然是原来那份手工加固过的单节点配置。
