-- Theme: dark (Catppuccin Macchiato + soft purple)
-- Applied by theme-switch; required from hyprland.lua.

hl.env("XCURSOR_THEME", "Adwaita")
hl.env("GTK_THEME", "adw-gtk3-dark")

hl.config({
    general = {
        col = {
            active_border = "rgba(9D8ECEcc)",
            inactive_border = "rgba(5b6078ff)",
        },
    },
    decoration = {
        dim_strength = 0.08,
        blur = {
            brightness = 0.8,
        },
    },
})
