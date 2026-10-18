#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

###############################################################################
# Amnezia OS customizations
# Base: Fedora 44 Kinoite (ghcr.io/ublue-os/kinoite-main:44)
###############################################################################

### 1. Applications we want -------------------------------------------------
## kate, ark and vim are already part of the base image; listing them keeps
## the image self-documenting and guarantees they stay.
dnf5 install -y \
    kate \
    gwenview \
    ark \
    mpv \
    vim-enhanced

### 2. Multimedia codecs ----------------------------------------------------
## The base image is built on negativo17's "fedora-multimedia" repository, so it
## already carries a *complete* ffmpeg (all the patent encumbered codecs),
## gstreamer1-plugin-libav, libva-intel-media-driver and Mesa with the VA-API
## drivers for AMD, Intel and NVIDIA compiled in. In Fedora 44 those drivers no
## longer live in a separate mesa-va-drivers package, they were merged into
## mesa-dri-drivers (radeonsi_drv_video.so, iHD_drv_video.so, ...).
##
## Playback of every common format, software and hardware accelerated, therefore
## already works here. There is nothing to add.
##
## We deliberately do NOT use RPM Fusion, which was tried and then removed: it
## does not mix with this base image at all.
##
##   1. RPM Fusion's GStreamer plugins link against an older x265
##      (libx265.so.215) than the one the base ships (4.2, libx265.so.216), so
##      dnf refuses the transaction outright.
##   2. mesa-va-drivers-freeworld drags RPM Fusion's entire Mesa stack (26.2.4,
##      no epoch) on top of negativo17's 1:26.2.3, and RPM Fusion builds no 32
##      bit packages whatsoever. The NVIDIA installer below installs 32 bit Mesa
##      for multilib, which then collides file for file with the 64 bit RPM
##      Fusion Mesa:
##        mesa-vulkan-drivers-1:26.2.3-1.fc44.i686 conflicts with
##        mesa-vulkan-drivers-26.2.4-1.fc44.x86_64
##      That one cannot be worked around: there is no 32 bit RPM Fusion Mesa to
##      go with it.
##
## The single piece the base does not ship is Cisco's openh264 plugin, which
## Fedora Workstation includes by default. It comes from the
## fedora-cisco-openh264 repo that is already present in the base image.
dnf5 install -y gstreamer1-plugin-openh264

### 3. Strip out what we don't want ------------------------------------------
## A lighter image is a faster image to update. Universal Blue's base is
## already lean (no office suite, no KDE PIM, no games as of Fedora 44), so
## this list is a safety net: it keeps those out if a future base image ever
## brings them back. Only packages that are really installed are handed to dnf.
REMOVE_PKGS=(
    # office suite
    libreoffice-calc libreoffice-writer libreoffice-impress libreoffice-draw
    libreoffice-core libreoffice-ure
    # KDE PIM / mail
    kmail kontact akregator korganizer kaddressbook knotes kdepim-runtime
    # music player
    elisa-player
    # games
    kpat kmahjongg kmines ksudoku kbounce ktuberling palapeli
)

installed=()
for pkg in "${REMOVE_PKGS[@]}"; do
    if rpm -q "${pkg}" >/dev/null 2>&1; then
        installed+=("${pkg}")
    fi
done

if ((${#installed[@]} > 0)); then
    echo "Removing: ${installed[*]}"
    dnf5 remove -y "${installed[@]}"
else
    echo "Nothing to remove: the base image is already lean."
fi

### 4. Services -------------------------------------------------------------
systemctl enable podman.socket

### 5. Sanity check ---------------------------------------------------------
## Everything the user explicitly asked for has to be there.
for pkg in kate gwenview ark mpv vim-enhanced; do
    rpm -q "${pkg}" >/dev/null || {
        echo "MISSING PACKAGE: ${pkg}"
        exit 1
    }
done
