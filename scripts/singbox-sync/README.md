# singbox-sync

A small, imperative subscription pipeline for `sing-box`.

It keeps the stable base config separate from subscription-generated nodes:
- base layer: `tun`, `dns`, `route`, local `clash_api`, logging
- generated layer: nodes from a Clash-style subscription, plus `selector` and `urltest`

This folder does **not** change the running service by itself. Your current `/etc/sing-box/config.json` stays untouched until you explicitly run `install-generated-config.sh`.

## Files

- `base.json`: stable base config that rarely changes
- `subscription.env.example`: template for the real secret file `subscription.env`
- `sync_subscription.py`: wrapper that converts the subscription into sing-box outbounds
- `update-subscription.sh`: fetch, convert, filter fake nodes, build final config, run `sing-box check`
- `install-generated-config.sh`: optional manual install step to replace `/etc/sing-box/config.json`
- `generated/config.json`: output file, intentionally gitignored

## One-Time Setup

1. Clone this dotfiles repo.
2. Prepare the converter once:

```bash
git clone --depth 1 https://github.com/NiuStar/sing-box-subscribe "$HOME/tools/sing-box-subscribe"
cd "$HOME/tools/sing-box-subscribe"
uv venv .venv
uv pip install --python .venv/bin/python -r requirements.txt
```

Notes:
- `update-subscription.sh` expects the converter at `$HOME/tools/sing-box-subscribe` by default.
- You can override it with `CONVERTER_DIR=/some/path`.
- The script auto-applies the small local parser patch we needed for subscriptions that contain `smux.enabled=true` but omit `smux.protocol`.

3. Create your real secret file locally, but do not commit it:

```bash
cd "$HOME/dotfiles/scripts/singbox-sync"
cp subscription.env.example subscription.env
$EDITOR subscription.env
```

## Normal Workflow

Generate a candidate config from the default subscription in `subscription.env`:

```bash
cd "$HOME/dotfiles/scripts/singbox-sync"
./update-subscription.sh
```

Or test a URL directly without touching `subscription.env`:

```bash
./update-subscription.sh 'https://example.com/subscription?token=...'
```

What the update step does:
- reads `base.json`
- downloads or reads the subscription source
- uses `sing-box-subscribe` to convert nodes
- filters metadata junk such as `剩余流量`, `官网`, `套餐到期`, and `127.0.0.1:1234` placeholders
- appends `auto` (`urltest`) and `proxy` (`selector`)
- writes `generated/config.json`
- runs `sing-box check`

## Selector Behavior

Generated config contains:
- `auto`: `type: urltest`
- `proxy`: `type: selector`

Current default policy is:
- `selector.default = first real node after metadata filtering`
- `auto` is available in the selector, but it is not the default

Why:
- fixed default is better for stable egress IP
- `auto` is useful as a fallback or temporary test path

If you want a different default later, edit `sync_subscription.py` in `build_final_config()`.

## Safe Switching

Recommended first switch:

1. Back up your current single-node config outside `/etc/sing-box`:

```bash
sudo cp /etc/sing-box/config.json /root/sing-box-config.single-sg1.json
```

2. Install the generated candidate config only when you actually want to switch:

```bash
cd "$HOME/dotfiles/scripts/singbox-sync"
sudo ./install-generated-config.sh
```

3. If needed, switch back:

```bash
sudo install -m 640 -o root -g sing-box /root/sing-box-config.single-sg1.json /etc/sing-box/config.json
sudo rm -f /var/lib/sing-box/cache.db
sudo systemctl restart sing-box
```

Important:
- do not keep extra `.json` backups inside `/etc/sing-box`
- your current service uses `sing-box -C /etc/sing-box`, so files in that directory may be loaded together

## NixOS Note

This generator is distro-agnostic. The generation step stays the same on NixOS:

```bash
cd "$HOME/dotfiles/scripts/singbox-sync"
./update-subscription.sh
```

Only the final install choice changes:
- imperative path: still copy the generated file to `/etc/sing-box/config.json`
- declarative path: keep this folder as the generator and feed `generated/config.json` into your Nix config when you are ready

## Current State On This Machine

Current running service was left unchanged on purpose.
The tested subscription-based candidate config lives here:
- `~/dotfiles/scripts/singbox-sync/generated/config.json`

The current online single-node config is still the manually hardened one unless you run the install script.
