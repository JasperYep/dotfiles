# Themes

`light/` and `dark/` hold theme-specific appearance settings.
Waybar shares `waybar.css` through symlinks in both theme directories; its
`colors.css` import loads the selected theme's palette. Layout and opacity are
shared; colors remain theme-specific.

Validate both Waybar themes with `/usr/bin/python tests/waybar-css.py` from the
repository root (requires GTK3/PyGObject).

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
