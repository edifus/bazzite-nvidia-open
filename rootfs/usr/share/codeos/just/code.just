# Give user access to docker socket
code-access-docker:
  #!/usr/bin/env bash
  set -euo pipefail
  sudo groupadd -r docker
  sudo usermod -aG docker $USER

# Install all Code OS apps
code-install: code-install-flatpaks code-install-nixpkgs

# Install only Flatpaks
code-install-flatpaks:
  #!/usr/bin/env bash
  set -euo pipefail

  echo "Installing Flatpaks..."
  xargs -a <(curl --retry 3 -sL https://raw.githubusercontent.com/edifus/bazzite/main/repo/flatpaks) flatpak --system -y install
  echo "Flatpaks installation complete."

# Install only Nix packages
code-install-nixpkgs:
  #!/usr/bin/env bash
  set -euo pipefail

  NIX_PROFILE="/nix/var/nix/profiles/default"
  NIX_DAEMON_SCRIPT="$NIX_PROFILE/etc/profile.d/nix-daemon.sh"

  # Source Nix daemon if available
  [ -f "$NIX_DAEMON_SCRIPT" ] && . "$NIX_DAEMON_SCRIPT"
  command -v nix &>/dev/null || ujust code-setup-nix

  echo "Installing Nix system fonts..."
  sudo -i nix profile install nixpkgs#nerd-fonts.{hack,iosevka,iosevka-term,jetbrains-mono,monoid,ubuntu,ubuntu-mono,ubuntu-sans,zed-mono}

  echo "Nix packages installation complete."

# Setup Nix package manager
code-setup-nix:
  #!/usr/bin/env bash
  set -euo pipefail

  NIX_DAEMON_SCRIPT="/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
  NIX_INSTALLER="https://install.determinate.systems/nix"

  echo "Setting up Nix package manager..."
  curl --proto '=https' --tlsv1.2 -sSf -L "$NIX_INSTALLER" | sh -s -- install --no-confirm
  [ -f "$NIX_DAEMON_SCRIPT" ] && . "$NIX_DAEMON_SCRIPT"
  echo "Nix setup complete."

# Setup Code OS recommended settings for Cursor and VSCode
code-setup-editors:
  #!/usr/bin/env bash
  set -euo pipefail

  for editor in "Cursor" "Code"; do
    echo "Setting up $editor configuration..."
    config_dir="${HOME}/.config/${editor}/User"
    mkdir -p "$config_dir"
    cp -f "/etc/skel/.config/${editor}/User/settings.json" "$config_dir/settings.json"
    echo "$editor setup complete."
  done

# Restart Bluetooth to fix issues
code-fix-bt:
  #!/usr/bin/env bash
  set -euo pipefail
  trap '[[ $BASH_COMMAND != echo* ]] && echo "+ $BASH_COMMAND"' DEBUG

  echo "Fixing Bluetooth..."
  sudo rfkill unblock all
  sudo rmmod btusb
  sudo modprobe btusb
  echo "Bluetooth fix complete."

# Manage SSD encryption optimizations (Workqueue and TRIM)
code-ssd-crypto:
  #!/usr/bin/env bash
  set -euo pipefail

  # Get LUKS2 devices
  luks_devices=$(sudo dmsetup ls --target crypt) || {
    echo "No LUKS devices found."
    exit 1
  }

  # Display devices and their settings
  echo "LUKS2 Devices and Settings:"
  echo "=========================="

  while read -r name _; do
    [ -z "$name" ] && continue

    status=$(sudo cryptsetup status "$name")
    device=$(echo "$status" | grep "device:" | cut -d: -f2 | xargs)

    # Skip if not LUKS2
    sudo cryptsetup isLuks --type luks2 "$device" 2>/dev/null || continue

    flags=$(echo "$status" | grep "flags:" | cut -d: -f2 | xargs)
    echo "Device: $name (${device})"
    echo "- TRIM: $(echo "$flags" | grep -q "discards" && echo "enabled" || echo "disabled")"
    echo "- No read workqueue: $(echo "$flags" | grep -q "no_read_workqueue" && echo "enabled" || echo "disabled")"
    echo "- No write workqueue: $(echo "$flags" | grep -q "no_write_workqueue" && echo "enabled" || echo "disabled")"
    echo "--------------------------"
  done <<<"$luks_devices"

  # Get and validate device selection
  read -p "Enter LUKS device name to optimize (or press Enter to exit): " device
  [ -z "$device" ] && exit 0

  if ! sudo cryptsetup status "$device" &>/dev/null; then
    echo "Error: Device $device not found"
    exit 1
  fi

  source_dev=$(sudo cryptsetup status "$device" | grep "device:" | cut -d: -f2 | xargs)
  if ! sudo cryptsetup isLuks --type luks2 "$source_dev" 2>/dev/null; then
    echo "Error: Device $device is not a LUKS2 device"
    exit 1
  fi

  # Check TRIM support
  supports_trim=$(sudo lsblk --pairs --discard "$source_dev" | head -n1 | grep -E 'DISC-GRAN="[1-9].*DISC-MAX="[1-9]')

  # Show menu options
  echo -e "\nSelect optimization option:"
  if [[ -n "$supports_trim" ]]; then
    options=(
      "Enable workqueue optimizations with TRIM"
      "Enable workqueue optimizations without TRIM"
      "Disable all optimizations"
    )
  else
    options=(
      "Enable workqueue optimizations"
      "Disable all optimizations"
    )
  fi

  for i in "${!options[@]}"; do
    echo "$((i + 1))) ${options[i]}"
  done

  read -p "Select option (1-${#options[@]}): " choice
  [[ ! "$choice" =~ ^[1-${#options[@]}]$ ]] && {
    echo "Invalid option"
    exit 1
  }

  # Apply selected optimization
  case $choice in
    1)
      if [[ -n "$supports_trim" ]]; then
        sudo cryptsetup --perf-no_read_workqueue --perf-no_write_workqueue --allow-discards --persistent refresh "$device"
        echo "✓ Workqueue optimizations enabled with TRIM"
      else
        sudo cryptsetup --perf-no_read_workqueue --perf-no_write_workqueue --persistent refresh "$device"
        echo "✓ Workqueue optimizations enabled"
      fi
      ;;
    2)
      if [[ -n "$supports_trim" ]]; then
        sudo cryptsetup --perf-no_read_workqueue --perf-no_write_workqueue --persistent refresh "$device"
        echo "✓ Workqueue optimizations enabled without TRIM"
      else
        sudo cryptsetup --persistent refresh "$device"
        echo "✓ All optimizations disabled"
      fi
      ;;
    3)
      sudo cryptsetup --persistent refresh "$device"
      echo "✓ All optimizations disabled"
      ;;
  esac

# Clean up old packages and Docker/Podman images and volumes
code-clean:
  #!/usr/bin/env bash
  set -euo pipefail

  echo "Cleaning up system..."
  docker system prune -af
  podman system prune -af
  flatpak uninstall --unused
  rpm-ostree cleanup -bm
  nix-collect-garbage -d
  sudo docker system prune -af
  sudo podman system prune -af
  sudo -i nix-collect-garbage -d
