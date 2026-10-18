# Amnezia OS

An atomic, immutable Linux desktop built on top of [Universal Blue](https://universal-blue.org/),
based on **Fedora 44 Kinoite** (KDE Plasma).

Everything is built from this repository by GitHub Actions and published as a
bootc/OCI container image on the GitHub Container Registry:

```
ghcr.io/amnezia-os/amnezia:latest
ghcr.io/amnezia-os/amnezia:44
```

> **Amnezia OS has nothing to do with any VPN product.** It is an independent
> desktop Linux distribution. The name is a personal project name only.

## What is inside

* Fedora 44 Kinoite with Universal Blue's tweaks (`ghcr.io/ublue-os/kinoite-main:44`)
* NVIDIA drivers, open flavour (`nvidia-open`, 615 series) — works on GeForce 16
  series and every RTX 20/30/40/50 series card, plus `nvidia-container-toolkit`
  so the GPU works inside containers too
* Multimedia: the base image already ships a full `ffmpeg` and VA-API drivers
  for AMD/Intel, RPM Fusion is enabled and `mesa-va-drivers-freeworld` is
  installed (the patent-enabled Mesa VA-API driver, which is what gives AMD
  GPUs hardware H.264/H.265 decoding), together with the Cisco openh264 plugin.
  NVIDIA brings its own VA-API through the driver below
* KDE applications: `kate`, `gwenview`, `ark`, `mpv`, plus `vim`
* All Flatpak preinstalls removed — the image stays the same on every machine
* No preinstalled office suite, KDE PIM (kmail/kontact), KDE games or Elisa.
  Universal Blue's base already ships none of them; `build_files/build.sh` keeps
  them out should a future base ever add them back
* Amnezia OS branding: wallpaper, look-and-feel and logo
* `/opt` is part of the image (not a symlink to `/var/opt`) so packages that
  install there survive updates

## Installing

Amnezia OS is a bootc image — you do not reinstall your system to try it, you
rebase onto it.

### From an existing bootc system

```bash
sudo bootc switch ghcr.io/amnezia-os/amnezia:latest
sudo systemctl reboot
```

Your previous system stays available in the boot menu, and you can always
switch back:

```bash
sudo bootc switch ghcr.io/ublue-os/kinoite-main:44
```

### From an ISO

Grab the Anaconda ISO from the releases / artifacts of the
[Build disk images](.github/workflows/build-disk.yml) workflow, boot it,
partition your disk the way you like (ext4 works fine) and install. The
installer will automatically point the new installation at
`ghcr.io/amnezia-os/amnezia:latest`.

## Verifying the image

Every image is signed with [cosign](https://docs.sigstore.dev/cosign/overview/)
using the project key at [`cosign.pub`](cosign.pub):

```bash
cosign verify --key https://raw.githubusercontent.com/amnezia-os/amnezia/main/cosign.pub \
  ghcr.io/amnezia-os/amnezia:latest
```

### Signature policy

The image also ships `/etc/containers/policy.json` with the public key above, so
that the system itself refuses anything from `ghcr.io/amnezia-os` that is not
signed with our key:

```
ghcr.io/amnezia-os -> sigstoreSigned, /etc/pki/containers/amnezia.pub
```

If you ever need to pull an unsigned image from that namespace (for example a
test build of your own), edit `/etc/containers/policy.json` and replace the
value of the `ghcr.io/amnezia-os` key with:

```json
[{ "type": "insecureAcceptAnything" }]
```

## Updating

Updates are built daily and applied like any other bootc system:

```bash
sudo bootc upgrade
sudo systemctl reboot
```

Images are [rechunked](https://coreos.github.io/rpm-ostree/build-chunked-oci/)
so updates only download the layers that actually changed.

## Building it yourself

The only requirements are `just`, `podman` and `jq`:

```bash
just build            # build the container image
sudo just build       # ...or build it straight into root's storage
just build-qcow2      # build a VM image (needs podman + bootc-image-builder)
just run-vm-qcow2     # boot that VM
just lint             # shellcheck
```

## Repository layout

| Path | What it is |
| --- | --- |
| `Containerfile` | the image: base image, NVIDIA stage, build script, lint |
| `build_files/build.sh` | packages to add/remove, codecs, services |
| `system_files/` | files copied into the image (`/etc`, `/usr`, branding) |
| `image-template.env` | image name, organisation, tags, description |
| `disk_config/iso.toml` | Anaconda ISO configuration |
| `.github/workflows/build.yml` | builds, rechunks, signs and pushes the image |
| `.github/workflows/build-disk.yml` | builds qcow2/ISO and uploads them to S3 |
| `branding/` | logos and wallpaper sources |

## Credits

Built with the [Universal Blue image template](https://github.com/ublue-os/image-template)
and [ublue-os/akmods](https://github.com/ublue-os/akmods).

## License

Apache-2.0 — see [LICENSE](LICENSE).
