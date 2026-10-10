#!/usr/bin/env python3
# Copy a vbmeta image with the AVB header flags set to
# HASHTREE_DISABLED|VERIFICATION_DISABLED (3), like
# `fastboot --disable-verity --disable-verification flash vbmeta`.
# The header is signed, so the result only boots on an unlocked device.
import struct, sys

src, dst = sys.argv[1], sys.argv[2]
data = bytearray(open(src, "rb").read())
if data[:4] != b"AVB0":
    sys.exit(f"{src}: not a vbmeta image")
old = struct.unpack_from(">I", data, 120)[0]
struct.pack_into(">I", data, 120, old | 3)
open(dst, "wb").write(data)
print(f"flags 0x{old:x} -> 0x{old | 3:x}")
