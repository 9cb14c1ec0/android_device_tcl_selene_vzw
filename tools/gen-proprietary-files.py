#!/usr/bin/env python3
"""Generate proprietary-files.txt for selene_vzw from an extracted stock vendor.

usage: gen-proprietary-files.py <stock dir containing vendor/> > proprietary-files.txt
"""
import os, re, struct, sys

root = sys.argv[1]
V = os.path.join(root, 'vendor')

# Provided by the LineageOS build (or regenerated), not blobs.
EXCLUDE = [
    r'build\.prop$', r'etc/selinux/',
    # VINTF manifests/matrix: device tree (configs/vintf), merged by the build
    r'etc/vintf/', r'odm/etc/vintf/', r'etc/fs_config_(dirs|files)$',
    r'etc/(group|passwd|mkshrc)$', r'etc/linker\.config\.pb$',
    r'bin/(awk|sh|toybox_vendor|toolbox|logwrapper|vndservice|vndservicemanager|dumpsys)$',
    r'bin/boringssl_self_test(32|64)$', r'etc/init/boringssl_self_test\.rc$',
    r'etc/init/vndservicemanager\.rc$',
    # init scripts / fstabs / ueventd live in the device tree (rootdir/)
    r'etc/init/hw/', r'etc/fstab\.', r'etc/ueventd\.rc$',
    r'lib/modules$',  # created by the build (BOARD_USES_VENDOR_DLKMIMAGE)
    # base_vendor.mk installs AOSP's (non-lazy) CAS service; both would
    # register IMediaCasService/default
    r'bin/hw/android\.hardware\.cas@1\.2-service-lazy$',
    r'etc/init/android\.hardware\.cas@1\.2-service-lazy\.rc$',
    r'overlay/.*\.apk$',  # RROs: prebuilt/overlay (prebuilt_overlay modules)
    # Boot control: hardware/mediatek's AIDL HAL (also needed in recovery)
    r'bin/hw/android\.hardware\.boot@1\.2-service$',
    r'etc/init/android\.hardware\.boot@1\.2-service\.rc$',
    r'lib(64)?/hw/android\.hardware\.boot@1\.0-impl-1\.2-mtkimpl\.so$',
    # AOSP builds of these stock tools are used instead (the stock leaf
    # libraries they replace are in exclude-libs.txt)
    r'bin/(dmabuf_dump|wpa_cli)$',
    # 32-bit Codec2 HAL: only the -64b service has an init script, so the
    # 32-bit service and the Codec2 libraries only it loads are never used
    r'bin/hw/android\.hardware\.media\.c2@1\.2-mediatek$',
    r'lib/(libcodec2_[^/]+|libsfplugin_ccodec_utils|libstagefright_bufferpool@2\.0\.1)\.so$',
    # 64-bit Android 13 Codec2 framework: compat/codec2-v33 ships these,
    # relinked, and every 64-bit Codec2 blob already uses those
    r'lib64/(libcodec2_vndk|libcodec2_soft_common|libsfplugin_ccodec_utils|'
    r'libcodec2_hidl@1\.[012]|libcodec2_hidl_plugin|libstagefright_bufferpool@2\.0\.1)\.so$',
]
# AOSP interface libraries (HIDL/AIDL, stable ABI) and generic AOSP vendor
# modules that base_vendor.mk/handheld_vendor.mk install anyway: the build
# provides them.
EXCLUDE_LIBS = open(os.path.join(os.path.dirname(__file__), 'exclude-libs.txt')).read().split()
EXCLUDE += [r'lib(64)?/(.+/)?(' + '|'.join(map(re.escape, EXCLUDE_LIBS)) + r')\.so$']
EXCLUDE = [re.compile(r'^vendor/' + e) for e in EXCLUDE]
APK = re.compile(r'\.apk$')
# Stock blobs whose names clash with AOSP source modules: keep the stock
# binary as a prebuilt module renamed with a _vendor suffix (installed under
# the original file name). No OVERRIDES: on Android 16 an override pulls the
# AOSP module's install deps (VINTF fragments, AIDL libs) into the staging
# directory, and with it into the target files and OTA.
COPY_ONLY_LIBS = open(os.path.join(os.path.dirname(__file__), 'copy-only-libs.txt')).read().split()
_names = '|'.join(map(re.escape, COPY_ONLY_LIBS))
COPY_ONLY = re.compile(r'^vendor/(lib(64)?/(.+/)?(' + _names + r')\.so|bin/(.+/)?(' + _names + r'))$')

# Stock blobs installed under a -v33 name instead: their AOSP namesakes
# would install to the same path (and, for HAL impls, their VINTF fragments).
# extract-files.py points the users at the new name.
RENAME = {}
RENAME.update({f'vendor/bin/hw/{b}': f'vendor/bin/hw/{b}-v33' for b in (
    'android.hardware.drm-service.clearkey',
    'android.hardware.health-service.example',
    'android.hardware.sensors-service.multihal',
    'wpa_supplicant',
)})
# Stock blobs at a path an AOSP vendor module also installs to
# (tools/v33-paths.txt). Prebuilts with a _vendor module name would still
# collide with the AOSP module's install and symbols/ outputs. Libraries also
# get a -v33 SONAME; tools/v33-needed.txt lists the blobs that link them.
V33_PATHS = open(os.path.join(os.path.dirname(__file__), 'v33-paths.txt')).read().split()
for f in V33_PATHS:
    RENAME[f] = f[:-3] + '-v33.so' if f.endswith('.so') else f + '-v33'
# Same collision, but loaded by file name (HIDL passthrough -impl and hw
# modules, media plugins), so they cannot be renamed: PRODUCT_COPY_FILES,
# which the build installs over the AOSP module (BUILD_BROKEN_DUP_RULES).
COPY_RULE_ONLY = set(open(os.path.join(os.path.dirname(__file__), 'copy-rule-only.txt')).read().split())

files, links = [], {}
for dp, dns, fns in os.walk(V):
    for n in dns + fns:
        p = os.path.join(dp, n)
        rel = os.path.relpath(p, root)
        if any(e.search(rel) for e in EXCLUDE):
            continue
        if os.path.islink(p):
            tgt = os.readlink(p)
            if tgt in ('toybox_vendor', 'toolbox'):
                continue
            absr = os.path.normpath(os.path.join(os.path.dirname(rel), tgt)) if not tgt.startswith('/') \
                else tgt.lstrip('/')
            links.setdefault(absr, []).append(rel)
        elif os.path.isfile(p):
            files.append(rel)

out, dangling = [], []
fileset = set(files)
for f in sorted(files):
    line = f
    m = COPY_ONLY.search(f)
    if f in RENAME:
        line += ':' + RENAME[f]
        if f.endswith('.so'):
            line += ';FIX_SONAME'
    elif f in COPY_RULE_ONLY:
        line += ';MAKE_COPY_RULE_ONLY'
    elif m:
        line += ';MODULE_SUFFIX=_vendor'
    elif APK.search(f):
        line += ';PRESIGNED'
    if f in links:
        line += ';SYMLINK=' + ','.join(sorted(links.pop(f)))
    out.append(line)
for tgt, srcs in sorted(links.items()):
    dangling += [f'{s} -> /{tgt}' for s in srcs]


def elf_needed(path):
    """(is64, DT_NEEDED list) of an ELF file, or None."""
    with open(path, 'rb') as fh:
        d = fh.read()
    if d[:4] != b'\x7fELF':
        return None
    is64 = d[4] == 2
    if is64:
        shoff, = struct.unpack_from('<Q', d, 0x28)
        shentsize, shnum = struct.unpack_from('<HH', d, 0x3A)
        sh, dyn = '<IIQQQQIIQQ', '<qQ'
    else:
        shoff, = struct.unpack_from('<I', d, 0x20)
        shentsize, shnum = struct.unpack_from('<HH', d, 0x2E)
        sh, dyn = '<IIIIIIIIII', '<iI'
    secs = [struct.unpack_from(sh, d, shoff + i * shentsize) for i in range(shnum)]
    needed = []
    for _, typ, _, _, off, size, link, _, _, _ in secs:
        if typ != 6:  # SHT_DYNAMIC
            continue
        stroff = secs[link][4]
        for o in range(off, off + size, struct.calcsize(dyn)):
            tag, val = struct.unpack_from(dyn, d, o)
            if tag == 0:
                break
            if tag == 1:  # DT_NEEDED
                needed.append(d[stroff + val:d.index(b'\0', stroff + val)].decode())
    return is64, needed


# Blobs that link a -v33 library: <installed path> <library>... (the library
# of the same bitness, by its stock name), for extract-files.py.
v33_libs = {(f.startswith('vendor/lib64/'), os.path.basename(f))
            for f in V33_PATHS if f.endswith('.so')}
with open(os.path.join(os.path.dirname(__file__), 'v33-needed.txt'), 'w') as fh:
    for f in sorted(files):
        if any(e.search(f) for e in EXCLUDE):
            continue
        elf = elf_needed(os.path.join(root, f))
        if not elf:
            continue
        libs = [n for n in elf[1] if (elf[0], n) in v33_libs]
        if libs:
            fh.write(' '.join([RENAME.get(f, f)] + libs) + '\n')

print('# Proprietary files for the TCL Tab 8 NxtPaper 5G (8189S / selene_vzw).')
print('#')
print('# All blobs are from the stock Verizon firmware (vendor partition):')
props = dict(l.split('=', 1) for l in open(os.path.join(V, 'build.prop')).read().splitlines()
             if '=' in l and not l.startswith('#'))
for p in ('ro.vendor.build.id', 'ro.vendor.build.version.incremental',
          'ro.vendor.build.security_patch'):
    print(f'#   {p}={props[p]}')
print('#')
print('# Generated by gen-proprietary-files.py; init scripts, fstabs, ueventd,')
print('# SELinux policy, VINTF manifest/matrix and props come from the device tree.')
print('#')
print('\n'.join(out))
for d in dangling:
    print(f'# symlink outside the blob set (handled in device.mk): {d}', file=sys.stderr)
