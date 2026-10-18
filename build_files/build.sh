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
## The base image already ships a full ffmpeg (negativo17's "fedora-multimedia"
## repo, pulled in by Universal Blue) plus VA-API drivers for AMD, Intel and
## NVIDIA, so playback of every common format already works.
##
## RPM Fusion is enabled for one specific reason: mesa-va-drivers-freeworld, the
## Mesa VA-API driver with the patent encumbered codecs turned on, which is what
## gives AMD GPUs hardware H.264/H.265 decoding. It is also simply useful to
## have RPM Fusion available.
FEDORA_VERSION="$(rpm -E %fedora)"
dnf5 install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VERSION}.noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VERSION}.noarch.rpm"

## NOTE: we deliberately do NOT install RPM Fusion's GStreamer plugins
## (gstreamer1-plugins-ugly, gstreamer1-plugins-bad-freeworld). Those link
## against an older x265 (libx265.so.215) than the one the base image ships
## (4.2, libx265.so.216), so dnf refuses the whole transaction. GStreamer
## already decodes everything through the base's gstreamer1-plugin-libav.

## mesa-va-drivers does not exist as a package in Fedora 44 any more (the
## VA-API drivers were merged into mesa-dri-drivers), but keep the swap logic
## for the day a future Fedora packages it separately again.
swap_if_installed() {
    local from="$1" to="$2"
    if rpm -q "${from}" >/dev/null 2>&1; then
        dnf5 swap -y "${from}" "${to}"
    else
        dnf5 install -y "${to}"
    fi
}

swap_if_installed mesa-va-drivers mesa-va-drivers-freeworld

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
for pkg in kate gwenview ark mpv vim-enhanced mesa-va-drivers-freeworld; do
    rpm -q "${pkg}" >/dev/null || {
        echo "MISSING PACKAGE: ${pkg}"
        exit 1
    }
done
