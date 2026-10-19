#!/usr/bin/env bash
# Reassemble Amnezia disk images downloaded from a GitHub release.
#
# GitHub rejects release assets of 2 GiB or more, so big images are published
# as <name>.part00, <name>.part01, ... Download every file from the release
# into one directory, then run this script inside that directory.
set -euo pipefail
cd "$(dirname "$0")"

shopt -s nullglob
found=0
for part in *.part00; do
    name="${part%.part00}"
    echo "==> собираю ${name}"
    cat "${name}".part* > "${name}"
    rm -f "${name}".part*
    found=1
done

if (( found == 0 )); then
    echo "нечего собирать: файлов .part00 рядом нет" >&2
    exit 1
fi

if [[ -f SHA256SUMS ]]; then
    echo "==> проверяю контрольные суммы"
    sha256sum -c SHA256SUMS
fi

echo
echo "готово. Дальше:"
echo "  ISO     — записать на флешку и загрузиться с неё"
echo "  qcow2   — qemu-system-x86_64 -enable-kvm -m 4096 -drive file=<файл>,if=virtio"
