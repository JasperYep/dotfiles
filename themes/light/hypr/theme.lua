-- Theme: light (Catppuccin Latte + soft purple)
-- Applied by theme-switch; required from hyprland.lua.

hl.env("XCURSOR_THEME", "Adwaita")
hl.env("GTK_THEME", "adw-gtk3")

hl.config({
    general = {
        col = {
            active_border = "rgba(9D8ECEcc)",
            inactive_border = "rgba(bcc0ccff)",
        },
    },
    decoration = {
        dim_strength = 0.03,
        blur = {
            brightness = 0.9,
        },
    },
})
