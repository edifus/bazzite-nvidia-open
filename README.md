[![Build Code OS](https://github.com/edifus/bazzite-nvidia-open/actions/workflows/build.yml/badge.svg)](https://github.com/edifus/bazzite-nvidia-open/actions/workflows/build.yml)

<div align="center">
  <picture>
    <source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/edifus/bazzite-nvidia-open/refs/heads/main/repo_files/code-logo-black.png">
    <img alt="Code OS Logo" src="https://raw.githubusercontent.com/edifus/bazzite-nvidia-open/refs/heads/main/repo_files/code-logo-white.png" width="100">
  </picture>
</div>

# Code OS

A custom Fedora Atomic image designed for gaming, development and daily use.

## Base System

- Built on Fedora 42
- Uses [bazzite-nvidia-open](https://bazzite.gg/) as the base image
- KDE Plasma 6.3 with Valve's themes from SteamOS

## Features

- [Bazzite features](https://github.com/ublue-os/bazzite#about--features)
- `cursor` and `cursor-cli` commands
- ADB, Fastboot and [Waydroid](https://docs.bazzite.gg/Installing_and_Managing_Software/Waydroid_Setup_Guide/)
- Audacious with Winamp skins
- Curated list of [Flatpaks](https://github.com/edifus/bazzite-nvidia-open/blob/main/repo/flatpaks)
- Docker, Podman, Distrobox and Toolbx
- Fixed Plasma integration with Google Drive
- Nix package manager
- OpenRGB and CoolerControl
- Switch to standalone SteamOS session from login screen
- Virtual Machine Manager, libvirt and QEMU
- VLC, mpv, HandBrake and Audacity
- Cursor (with Remote Tunnels fixed)

## Install

From existing Fedora Atomic/Universal Blue installation switch to Code OS image:

```bash
sudo bootc switch --enforce-container-sigpolicy ghcr.io/edifus/bazzite-nvidia-open:latest
```

If you want to install the image on a new system download and install Bazzite ISO first:

<https://download.bazzite.gg/bazzite-stable-amd64.iso>

## Custom commands

The following `ujust` commands are available:

```bash
# Clean up old packages and Docker/Podman images and volumes
ujust code-clean

# Install all Code OS apps
ujust code-install

# Install only Flatpaks
ujust code-install-flatpaks

# Install only Nix packages
ujust code-install-nixpkgs

# Setup Code OS settings for Cursor and VSCode
ujust code-setup-editors

# Setup Nix package manager
ujust code-setup-nix

# Restart Bluetooth to fix issues
ujust code-fix-bt

# Manage SSD encryption optimizations (Workqueue and TRIM)
ujust code-ssd-crypto
```

## Package management

GUI apps can be found as Flatpaks in the Discover app or [FlatHub](https://flathub.org/) and installed with `flatpak install ...`.

CLI apps are available from [Nix](https://search.nixos.org/packages) using `nix profile install nixpkgs#...`. GUI apps usually work fine too.

## Acknowledgments

This project is based on the [Universal Blue image template](https://github.com/ublue-os/image-template) and builds upon the excellent work of the Universal Blue community.
