# Amnezia OS
# A custom Universal Blue image, based on Fedora 44 Kinoite.
#
# Everything that is *installed* or *configured* lives in:
#   build_files/build.sh   -> package changes, removals, services
#   system_files/          -> files copied verbatim into the image (/etc, /usr, ...)

# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files

# ---------------------------------------------------------------------------
# NVIDIA kernel modules + userspace driver.
#
# Universal Blue's akmods project pre-builds the NVIDIA driver for the exact
# kernel our base image ships, so nothing needs to be compiled here.
# Tag format is `main-<fedora version>-<arch>`; `main` means the mainline
# Fedora kernel. We use the "open" driver flavour: it supports Turing and
# newer, which covers GeForce 16 series (including the GTX 1650 Mobile) and
# every RTX 20/30/40/50 series card.
#
# NOTE: the kernel inside this akmods image has to match the kernel of our
# base image. Both are rebuilt daily by Universal Blue, and the build will
# fail loudly below if they ever drift apart.
# ---------------------------------------------------------------------------
FROM ghcr.io/ublue-os/akmods-nvidia-open:main-44-x86_64 AS akmods-nvidia

# Base Image
FROM ghcr.io/ublue-os/kinoite-main:44

### [IM]MUTABLE /opt
## On Fedora bootc images /opt is a symlink to /var/opt, which makes it
## writable but means its contents can be wiped when a new image is deployed.
## Turning it into a real directory makes it part of the image, so packages
## that install into /opt survive updates.
RUN rm /opt && mkdir /opt

### MODIFICATIONS
## Make modifications and install packages by editing build_files/build.sh.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

### NVIDIA DRIVERS
## The akmods image ships `nvidia-install.sh` together with the matching RPMs.
## It needs to find the RPMs at /tmp/akmods-rpms and an IMAGE_NAME.
## We pass IMAGE_NAME=kinoite so the installer applies the same treatment it
## uses for Universal Blue's own Kinoite-based image (that also pulls in
## supergfxctl, which is used by hybrid graphics laptops such as this one).
RUN --mount=type=bind,from=akmods-nvidia,source=/rpms,target=/tmp/akmods-rpms \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    IMAGE_NAME=kinoite /tmp/akmods-rpms/ublue-os/nvidia-install.sh

### VERIFY THE NVIDIA MODULE MATCHES OUR KERNEL
## If Universal Blue's akmods build lags behind the base image kernel, the
## module would simply not load at boot and NVIDIA would silently be broken.
## Fail the build instead of publishing such an image; the fix is to simply
## re-run the workflow a few hours later.
RUN kver="$(rpm -q --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' kernel | head -n1)" \
 && mver="$(rpm -q --queryformat '%{VERSION}' kmod-nvidia | head -n1)" \
 && echo "kernel in image : ${kver}" \
 && echo "kernel of kmod  : ${mver}" \
 && test "${kver}" = "${mver}"

### RE-ENABLE THE REPOS THE NVIDIA INSTALLER TURNED OFF
## The installer disables RPM Fusion on purpose (so that its own driver packages
## win) and also disables the Cisco openh264 repo. We want both available again
## afterwards: RPM Fusion is where our codecs come from.
RUN dnf5 config-manager setopt "rpmfusion*".enabled=1 fedora-cisco-openh264.enabled=1

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
