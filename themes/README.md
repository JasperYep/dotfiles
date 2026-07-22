# Themes

`light/` and `dark/` are the only appearance sources.

`theme-switch` stores the selected theme as:

```text
~/.config/theme/current -> ~/dotfiles/themes/light|dark
```

Applications either read that directory directly or use stable symlinks managed by
`theme-switch`. Switching themes must never copy files into this repository.

```bash
theme-switch light
theme-switch dark
theme-switch toggle
theme-switch status
```

After either switch, `git status --porcelain` must remain empty.
