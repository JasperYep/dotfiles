# dotfiles

Restore my Hyprland workstation environment from a base Arch Linux installation that has already been updated and configured for the machine's hardware.

## Quick Restore (Core Desktop)

Run as a regular user to restore only the essential desktop, shell, and editor environment:

```bash
sudo pacman -S --needed git base-devel && \
git clone https://github.com/JasperYep/dotfiles ~/dotfiles && \
~/dotfiles/bootstrap.sh
```

After the bootstrap completes, log out and log back in on TTY1:

```bash
start-hyprland
~/dotfiles/verify.sh --session
```

## Optional Work Profiles

Heavy tools (TeX Live, VS Code application, Android Studio, office suites, AI CLIs, etc.) are split into optional profiles so fresh machine restores stay fast:

```bash
# Preview what will be installed
~/dotfiles/bootstrap.sh --plan

# List supported profiles
~/dotfiles/bootstrap.sh --list-profiles

# Install core environment plus selected profiles
~/dotfiles/bootstrap.sh --with academic,dev

# Install core and all profiles
~/dotfiles/bootstrap.sh --full
```

Supported profiles: `academic`, `documents`, `dev`, `ai`, `media`, `communication`, `infra`, `remote`.

This repository restores user-facing software, dotfiles, and user services. It does not upgrade the system or modify the kernel, drivers, or bootloader. Store machine-specific configuration in `~/.config/hypr/host.lua` and restore private data separately.

Detailed boundaries: [restore scope](docs/scope.md) · [private data restoration](docs/private-restore.md)
