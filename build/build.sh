#!/usr/bin/bash
set -ouex pipefail

trap '[[ $BASH_COMMAND != echo* ]] && [[ $BASH_COMMAND != log* ]] && echo "+ $BASH_COMMAND"' DEBUG

log() {
  echo "=== $* ==="
}
log "Starting Code OS build process"

### Workaround for installing nix
mkdir /nix

### Install packages

# gamescope session plus
mkdir -p /usr/share/gamescope-session-plus/
curl -Lo /usr/share/gamescope-session-plus/bootstrap_steam.tar.gz https://large-package-sources.nobaraproject.org/bootstrap_steam.tar.gz
dnf5 install --enable-repo="copr:copr.fedorainfracloud.org:bazzite-org:bazzite" -y \
  gamescope-session-plus \
  gamescope-session-steam

# ghostty terminal
log "Building ghostty terminal from source"
workdir=$(pwd)
dnf5 install -y blueprint-compiler gettext gtk4-devel libadwaita-devel zig-0.13.0-8.fc42
git clone https://github.com/ghostty-org/ghostty
cd ghostty && git checkout v1.1.3
zig build -p /usr -Doptimize=ReleaseFast
cd $workdir && rm -rf ghostty

# vscode
log "Installing vscode"
dnf5 config-manager addrepo --set=baseurl="https://packages.microsoft.com/yumrepos/vscode" --id="vscode"
dnf5 config-manager setopt vscode.enabled=0
# FIXME: gpgcheck is broken for vscode due to it using `asc` for checking
# seems to be broken on newer rpm security policies.
dnf5 config-manager setopt vscode.gpgcheck=0
dnf5 install --nogpgcheck --enable-repo="vscode" -y code

# RPM packages list
declare -A RPM_PACKAGES=(
  ["fedora"]="\
    android-tools \
    aria2 \
    bchunk \
    bleachbit \
    fuse-btfs \
    fuse-devel \
    fuse3-devel \
    gnome-disk-utility \
    gparted \
    gwenview \
    isoimagewriter \
    kcalc \
    kgpg \
    ksystemlog \
    nmap \
    openrgb \
    plymouth-plugin-script \
    printer-driver-brlaser \
    qemu-kvm \
    virt-manager \
    virt-viewer \
    wireshark \
    yakuake \
    yt-dlp \
    zsh"

  ["terra"]="\
    coolercontrol"

  ["rpmfusion-free,rpmfusion-free-updates,rpmfusion-nonfree,rpmfusion-nonfree-updates"]="\
    audacity-freeworld"

  ["fedora-multimedia"]="\
    HandBrake-cli \
    HandBrake-gui \
    haruna \
    mpv \
    vlc-plugin-bittorrent \
    vlc-plugin-ffmpeg \
    vlc-plugin-kde \
    vlc-plugin-pause-click \
    vlc"
)

log "Installing RPM packages"
mkdir -p /var/opt
for repo in "${!RPM_PACKAGES[@]}"; do
  read -ra pkg_array <<<"${RPM_PACKAGES[$repo]}"
  if [[ $repo == copr:* ]]; then
    # Handle COPR packages
    copr_repo=${repo#copr:}
    dnf5 -y copr enable "$copr_repo"
    dnf5 -y install "${pkg_array[@]}"
    dnf5 -y copr disable "$copr_repo"
  else
    # Handle regular packages
    [[ $repo != "fedora" ]] && enable_opt="--enable-repo=$repo" || enable_opt=""
    cmd=(dnf5 -y install)
    [[ -n "$enable_opt" ]] && cmd+=("$enable_opt")
    cmd+=("${pkg_array[@]}")
    "${cmd[@]}"
  fi
done

# setup docker
docker_pkgs=(
    containerd.io
    docker-buildx-plugin
    docker-ce
    docker-ce-cli
    docker-compose-plugin
)
dnf5 config-manager addrepo --from-repofile="https://download.docker.com/linux/fedora/docker-ce.repo"
dnf5 config-manager setopt docker-ce-stable.enabled=0
dnf5 install -y --enable-repo="docker-ce-stable" "${docker_pkgs[@]}" || {
    # Use test packages if docker pkgs is not available for f42
    if (($(lsb_release -sr) == 42)); then
        echo "::info::Missing docker packages in f42, falling back to test repos..."
        dnf5 install -y --enablerepo="docker-ce-test" "${docker_pkgs[@]}"
    fi
}

# Load iptable_nat module for docker-in-docker.
# See:
#   - https://github.com/ublue-os/bluefin/issues/2365
#   - https://github.com/devcontainers/features/issues/1235
mkdir -p /etc/modules-load.d && cat >>/etc/modules-load.d/ip_tables.conf <<EOF
iptable_nat
EOF

# docker sysusers.d
echo -e "#Type Name   ID\ng     docker -" | tee /usr/lib/sysusers.d/docker.conf

# Enable systemd services
log "Enabling system services"
systemctl enable docker.socket libvirtd.service

# Install Cursor GUI
log "Installing Cursor GUI"
GUI_DIR="/tmp/cursor-gui"
mkdir -p "$GUI_DIR"
DOWNLOAD_URL=$(curl -s "https://www.cursor.com/api/download?platform=linux-x64&releaseTrack=stable" | grep -o '"downloadUrl":"[^"]*' | cut -d'"' -f4)
if [[ -z "$DOWNLOAD_URL" ]]; then
  echo "Failed to extract download URL from JSON response"
  exit 1
fi
aria2c --dir="$GUI_DIR" --out="cursor.appimage" --max-tries=3 --connect-timeout=30 "$DOWNLOAD_URL"
chmod +x "$GUI_DIR/cursor.appimage"
(cd "$GUI_DIR" && ./cursor.appimage --appimage-extract)
chmod -R a+rX "$GUI_DIR/squashfs-root"
cp -r "$GUI_DIR/squashfs-root/usr/share/icons/"* /usr/share/icons
mkdir -p /usr/share/cursor/bin
cp -r "$GUI_DIR/squashfs-root/usr/share/cursor/"* /usr/share/cursor
install -m 0755 /usr/share/cursor/resources/linux/bin/cursor /usr/share/cursor/bin/cursor
ln -s /usr/share/cursor/bin/cursor /usr/bin/cursor

# Install Cursor CLI
log "Installing Cursor CLI"
CLI_DIR="/tmp/cursor-cli"
mkdir -p "$CLI_DIR"
aria2c --dir="$CLI_DIR" --out="cursor-cli.tar.gz" --max-tries=3 --connect-timeout=30 "https://api2.cursor.sh/updates/download-latest?os=cli-alpine-x64"
tar -xzf "$CLI_DIR/cursor-cli.tar.gz" -C "$CLI_DIR"
install -m 0755 "$CLI_DIR/cursor" /usr/share/cursor/bin/cursor-tunnel
ln -s /usr/share/cursor/bin/cursor-tunnel /usr/bin/cursor-cli
ln -s /usr/share/cursor/bin/cursor-tunnel /usr/share/cursor/bin/code-tunnel

# Import just recipes
log "Adding Code OS just recipes"
echo "import \"/usr/share/codeos/just/code.just\"" >>/usr/share/ublue-os/justfile

# Hide irrelevant bazzite recipes
log "Hide incompatible Bazzite just recipes"
for recipe in "bazzite-cli" "install-coolercontrol" "install-openrgb"; do
  if ! grep -l "^$recipe:" /usr/share/ublue-os/just/*.just | grep -q .; then
    echo "Error: Recipe $recipe not found in any just file"
    exit 1
  fi
  sed -i "s/^$recipe:/_$recipe:/" /usr/share/ublue-os/just/*.just
done

log "Build process completed"
