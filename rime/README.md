# macOS Rime (Squirrel)

This module contains the user-maintained Rime configuration for macOS Squirrel.

It intentionally excludes generated data and machine-local state such as `build/`,
`user.yaml`, `installation.yaml`, `sync/`, and `*.userdb/`.

Restore manually on macOS with:

```bash
cp -R ~/dotfiles/rime/Library/Rime/. ~/Library/Rime/
/Library/Input\ Methods/Squirrel.app/Contents/MacOS/Squirrel --reload
```
