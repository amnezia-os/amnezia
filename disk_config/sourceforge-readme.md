# Amnezia OS — disk images

Amnezia is Fedora 44 Kinoite with the NVIDIA driver baked in. The installed
system updates itself from `ghcr.io/amnezia-os/amnezia:latest`; you do not
reinstall to upgrade.

## Which file do I need?

| File | What it is |
|---|---|
| `*.iso` | Anaconda installer. Boot it, choose your own partitioning, install. The installer points the new system at the Amnezia image, so it updates normally afterwards. |
| `*.qcow2` | Ready-made virtual disk for QEMU/KVM. Root filesystem is ext4, 30 GiB virtual size. |
| `*CHECKSUM*` | SHA-256 of the image. Verify it before installing. |

## Verify the download

```bash
sha256sum -c <file>.iso-x86_64-CHECKSUM
```

The container image itself is signed with cosign:

```bash
cosign verify --key https://raw.githubusercontent.com/amnezia-os/amnezia/main/cosign.pub \
  ghcr.io/amnezia-os/amnezia:latest
```

## Notes

- Default root filesystem is **ext4**. `bootc install to-disk --filesystem btrfs`
  (or `xfs`) works too.
- The ISO does not create a user for you — Anaconda asks for one during
  installation.
- Only amd64 (x86_64) images are published.

Source: <https://github.com/amnezia-os/amnezia>
