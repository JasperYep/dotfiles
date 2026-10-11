# Themes

`light/` and `dark/` hold theme-specific appearance settings.
Waybar shares `waybar.css` through symlinks in both theme directories; its
`colors.css` import loads the selected theme's palette. Layout and opacity are
shared; colors remain theme-specific.

Desktop surfaces use opaque backgrounds, restrained borders and 8px outer
corners. Waybar has no panel container, border or background: its text and
underline indicators sit on the upper sky of the theme wallpaper. Window focus
uses a slate border, not opacity or dimming. Light and dark share geometry but
use different backgrounds: `light/wallpaper.jpg` is the pale misty range,
`dark/wallpaper.jpg` the nocturnal peak. Both are 3840x2160 with a clean upper
band so Waybar text stays legible. `theme-switch` reloads the running
`hyprpaper` so the change is visible immediately; applications change between
mist and slate.

Validate both Waybar themes with `/usr/bin/python tests/waybar-css.py` from the
repository root (requires GTK3/PyGObject).

`theme-switch` stores the selected theme as:

```text
~/.config/theme/current -> ~/dotfiles/themes/light|dark
```

Applications either read that directory directly or use stable symlinks managed by
`theme-switch`. Ghostty and foot carry both palettes and pick the active one
from the theme tree: `theme-switch` reloads running Ghostty over D-Bus and tells
foot which palette to use (SIGUSR1 dark, SIGUSR2 light), while new terminals read
`~/.config/theme/current/foot/theme.ini` for their initial theme. Switching
themes must never copy files into this repository.

```bash
theme-switch light
theme-switch dark
theme-switch toggle
theme-switch status
```

Switching must not introduce Git changes (an initially clean worktree stays clean).
