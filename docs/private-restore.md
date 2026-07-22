# Private restore boundary

公共dotfiles不会保存或恢复以下内容：

- SSH/GPG private keys、tokens、passwords和desktop keyring
- browser profile、cookies、sessions和shell history
- research code/data、paper working tree、datasets、models和application state
- Zotero library/data directory
- proxy subscription、generated proxy config和network enrollment state
- private systemd environment files与private services
- Rime learned dictionary、sync data、build output、`installation.yaml`和`user.yaml`
- `tt`真实日程

## Rime

认证GitHub后，把私人Rime仓库恢复到：

```text
~/.local/share/fcitx5/rime
```

然后在该仓库中运行它自己的bootstrap，并执行：

```bash
fcitx5-remote -r
```

公共bootstrap只恢复Fcitx5 profile、hotkeys和非私人的UI配置。

## tt

真实日程文件位于：

```text
~/.config/tt/schedule.json
```

结构参考仓库中的`tt/.config/tt/schedule.example.json`。文件恢复并通过`tt validate`后，可以执行：

```bash
systemctl --user enable --now tt.service
```

## 验证原则

私人层恢复完成后，应单独确认credential权限、remote access、research data完整性和private service状态；公共`verify.sh`不会把这些未观察到的结果报告为成功。
