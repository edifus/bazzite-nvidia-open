#!/bin/bash
set -ouex pipefail

trap '[[ $BASH_COMMAND != echo* ]] && [[ $BASH_COMMAND != log* ]] && echo "+ $BASH_COMMAND"' DEBUG

log() {
  echo "=== $* ==="
}

### Apply random plymoth theme on build
theme_list=(
    "abstract_ring"
    "abstract_ring_alt"
    "angular_alt"
    "blockchain"
    "circle"
    "circle_flow"
    "circuit"
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

log "Applying plymouth theme $theme"
plymouth-set-default-theme $theme
