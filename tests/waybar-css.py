#!/usr/bin/python
"""Run with /usr/bin/python tests/waybar-css.py (requires GTK3/PyGObject)."""
from pathlib import Path

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk

root = Path(__file__).resolve().parents[1]
for theme in ("light", "dark"):
    style = root / "themes" / theme / "waybar/style.css"
    assert style.is_symlink()
    assert style.resolve() == root / "themes/waybar.css"
    errors = []
    provider = Gtk.CssProvider()
    provider.connect("parsing-error", lambda provider, section, error: errors.append(error))
    provider.load_from_path(str(style))
    assert not errors, (theme, errors)
    context = Gtk.StyleContext()
    context.add_provider(provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
    found, accent = context.lookup_color("accent")
    assert found, theme
    expected = "#9D8ECE" if theme == "light" else "#B2A4D4"
    from gi.repository import Gdk
    color = Gdk.RGBA()
    assert color.parse(expected)
    assert accent.equal(color), (theme, accent.to_string())
    print(f"{theme}: shared stylesheet and GTK CSS valid")
