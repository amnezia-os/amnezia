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
## The base image ships a full ffmpeg (negativo17's "fedora-multimedia" repo)
## but no RPM Fusion. RPM Fusion is where the *hardware accelerated* H.264 /
## H.265 decoding for AMD (and the full GStreamer plugin set) lives, so add it
## the way RPM Fusion itself documents it.
FEDORA_VERSION="$(rpm -E %fedora)"
dnf5 install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VERSION}.noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VERSION}.noarch.rpm"

## mesa-va-drivers-freeworld is Mesa's VA-API driver with the patent
## encumbered codecs enabled: this is what gives AMD GPUs hardware video
## decoding. (Intel is already covered by libva-intel-media-driver, NVIDIA by
## the driver we install below.) The Fedora build of the same package has to
## be swapped out, hence the helper.
swap_if_installed() {
    local from="$1" to="$2"
    if rpm -q "${from}" >/dev/null 2>&1; then
        dnf5 swap -y "${from}" "${to}"
    else
        dnf5 install -y "${to}"
    fi
}

swap_if_installed mesa-va-drivers mesa-va-drivers-freeworld

dnf5 install -y \
    gstreamer1-plugins-bad-freeworld \
    gstreamer1-plugins-ugly \
    gstreamer1-plugin-openh264

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
