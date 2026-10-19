# Amnezia OS disk images

Amnezia is Fedora 44 Kinoite with the NVIDIA driver baked in. The installed
system updates itself from `ghcr.io/amnezia-os/amnezia:latest` — you do not
reinstall to upgrade.

## Downloading

GitHub caps a release asset at 2 GiB, so large images are published in parts.
Download **every** file from this release into one directory, then run:

```bash
bash download.sh
```

The script joins the parts back into whole images and verifies their SHA-256.

## Which file do I need?

| File | What it is |
|---|---|
| `*.iso` | Anaconda installer. Boot it, partition your disk as you like, install. The installer points the new system at the Amnezia image, so updates work afterwards. |
| `*.qcow2` | Ready-made virtual disk for QEMU/KVM. Root filesystem is ext4, 30 GiB virtual size. |
| `SHA256SUMS` | Checksums of the complete (joined) images. |

## Notes

- Default root filesystem is **ext4**; `bootc install to-disk --filesystem btrfs`
  (or `xfs`) works too.
- The ISO does not create a user account — Anaconda asks for one during
  installation.
- Only amd64 (x86_64) images are published.
- The container image is signed with cosign:

  ```bash
  cosign verify --key https://raw.githubusercontent.com/amnezia-os/amnezia/main/cosign.pub \
    ghcr.io/amnezia-os/amnezia:latest
  ```

Source: <https://github.com/amnezia-os/amnezia>
