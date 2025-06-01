#!/bin/bash
set -ouex pipefail

trap '[[ $BASH_COMMAND != echo* ]] && [[ $BASH_COMMAND != log* ]] && echo "+ $BASH_COMMAND"' DEBUG

log() {
  echo "=== $* ==="
}
log "Starting Code OS build process"

### Apply random plymoth theme on build
theme_list=(
    "abstract_ring"
    "abstract_ring_alt"
    "angular_alt"
    "blockchain"
    "circle"
    "cubes"
    "deus_ex"
    "green_blocks"
    "hexagon"
    "hexagon_2"
    "hexagon_alt"
    "lone"
    "sphere"
    "splash"
    "square"
)

theme=$(printf "%s\n" "${theme_list[@]}" | shuf -n 1)

plymouth-set-default-theme $theme
