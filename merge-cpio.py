#!/usr/bin/env python3
"""Merge newc cpio archives into one.

Stock selene_vzw vendor_boot carries ONE unnamed platform ramdisk that holds
the recovery root plus first_stage_ramdisk/ (normal-boot first stage) and
lib/modules/ (first-stage kernel modules for both boot modes).

    merge-cpio.py OUT BASE.cpio [--keep PREFIX ...] OVERLAY.cpio [...]

Entries from BASE are kept only if they match a --keep prefix. Every entry
from each OVERLAY is kept. Later archives win on path collisions, except
that paths kept from BASE are never replaced (so stock modules / first
stage files stay byte-identical).
"""

import argparse
import sys

MAGIC = b"070701"
HDR_LEN = 110


def pad4(n):
    return (4 - n % 4) % 4


def read_cpio(path):
    data = open(path, "rb").read()
    off = 0
    entries = []
    while True:
        if data[off:off + 6] != MAGIC:
            raise SystemExit(f"{path}: bad cpio magic at {off:#x}")
        f = [int(data[off + 6 + i * 8:off + 14 + i * 8], 16) for i in range(13)]
        mode, uid, gid, nlink, mtime, fsize = f[1], f[2], f[3], f[4], f[5], f[6]
        rdevmajor, rdevminor, namesize = f[9], f[10], f[11]
        off += HDR_LEN
        name = data[off:off + namesize - 1].decode()
        off += namesize + pad4(HDR_LEN + namesize)
        body = data[off:off + fsize]
        off += fsize + pad4(fsize)
        if name == "TRAILER!!!":
            break
        if nlink > 1 and fsize == 0 and (mode & 0o170000) == 0o100000:
            raise SystemExit(f"{path}: hardlinked entry {name} not supported")
        name = name.lstrip("./") if name not in (".", "") else name
        entries.append(dict(name=name, mode=mode, uid=uid, gid=gid,
                            mtime=mtime, rmaj=rdevmajor, rmin=rdevminor,
                            body=body))
    return entries


def write_cpio(path, entries):
    out = bytearray()
    ino = 300000

    def emit(e, name):
        nonlocal ino
        ino += 1
        nb = name.encode() + b"\0"
        is_dir = (e["mode"] & 0o170000) == 0o040000
        hdr = MAGIC + b"".join(b"%08x" % v for v in (
            ino, e["mode"], e["uid"], e["gid"], 2 if is_dir else 1,
            e["mtime"], len(e["body"]), 0, 0, e["rmaj"], e["rmin"],
            len(nb), 0))
        out.extend(hdr + nb + b"\0" * pad4(HDR_LEN + len(nb)))
        out.extend(e["body"] + b"\0" * pad4(len(e["body"])))

    for e in entries:
        emit(e, e["name"])
    emit(dict(mode=0, uid=0, gid=0, mtime=0, rmaj=0, rmin=0, body=b""),
         "TRAILER!!!")
    open(path, "wb").write(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("base")
    ap.add_argument("--keep", action="append", default=[])
    ap.add_argument("overlays", nargs="+")
    a = ap.parse_args()

    merged = {}
    order = []
    pinned = set()

    def matches(name):
        return any(name == k or name.startswith(k.rstrip("/") + "/")
                   for k in a.keep)

    for e in read_cpio(a.base):
        if matches(e["name"]):
            merged[e["name"]] = e
            order.append(e["name"])
            pinned.add(e["name"])
    for ov in a.overlays:
        for e in read_cpio(ov):
            n = e["name"]
            if n in pinned:
                if (e["mode"] & 0o170000) != 0o040000:
                    print(f"note: keeping stock {n}, ignoring overlay copy",
                          file=sys.stderr)
                continue
            if n not in merged:
                order.append(n)
            merged[n] = e

    # Parents before children for the kernel unpacker.
    order.sort(key=lambda n: (n.count("/"), n))
    write_cpio(a.out, [merged[n] for n in order])
    print(f"{a.out}: {len(order)} entries ({len(pinned)} from stock)",
          file=sys.stderr)


if __name__ == "__main__":
    main()
