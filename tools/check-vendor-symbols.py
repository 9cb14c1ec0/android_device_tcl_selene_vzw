#!/usr/bin/env python3
"""Offline ABI check for the rebuilt vendor image.

For every ELF in <out>/vendor (stock blobs and source-built modules alike),
follow DT_NEEDED the way the vendor linker namespace would (vendor/odm lib
dirs first, then LLNDK libraries from /system), and report undefined,
non-weak dynamic symbols that no library in the dependency closure defines.
Those are the places where Android 15 libraries broke the ABI the Android 13
blobs were linked against, and need a -v33 compat lib or a shim.

usage: check-vendor-symbols.py [out/target/product/selene_vzw]
"""
import os
import subprocess
import sys
from functools import lru_cache

OUT = sys.argv[1] if len(sys.argv) > 1 else 'out/target/product/selene_vzw'
NM = os.environ.get('LLVM_NM', 'prebuilts/clang/host/linux-x86/clang-r536225/bin/llvm-nm')
READELF = os.environ.get('LLVM_READELF', 'prebuilts/clang/host/linux-x86/clang-r536225/bin/llvm-readelf')

# Libraries vendor code may load from the system side (LLNDK + bionic).
LLNDK_DIRS = ['system/{lib}', 'system/{lib}/bootstrap']
# bionic lives in the runtime APEX; not checked (A15 libc is a superset).
SKIP_LIBS = {'libc.so', 'libm.so', 'libdl.so', 'ld-android.so'}


def vendor_dirs(lib):
    return [f'vendor/{lib}', f'vendor/{lib}/hw', f'vendor/{lib}/egl',
            f'vendor/odm/{lib}', f'vendor/{lib}/mt6835']


def run(tool, *args):
    r = subprocess.run([tool, *args], capture_output=True, text=True)
    return r.stdout


def is_elf(path):
    try:
        with open(path, 'rb') as f:
            return f.read(4) == b'\x7fELF'
    except OSError:
        return False


def elf_class(path):
    with open(path, 'rb') as f:
        f.seek(4)
        return 'lib64' if f.read(1) == b'\x02' else 'lib'


@lru_cache(maxsize=None)
def needed(path):
    out = run(READELF, '-d', path)
    return tuple(l.split('[', 1)[1].rstrip(']').strip()
                 for l in out.splitlines() if '(NEEDED)' in l)


@lru_cache(maxsize=None)
def defined(path):
    syms = set()
    for l in run(NM, '-D', '--defined-only', '--format=just-symbols', path).splitlines():
        syms.add(l.split('@')[0])
    return frozenset(syms)


@lru_cache(maxsize=None)
def undefined(path):
    syms = set()
    for l in run(NM, '-D', '--undefined-only', path).splitlines():
        parts = l.split()
        if len(parts) >= 2 and parts[0] == 'U':
            syms.add(parts[1].split('@')[0])
    return frozenset(syms)


# Extra library dirs searched after vendor and system, e.g. a VNDK APEX
# payload or the i18n APEX ('{lib}' expands to lib/lib64), colon-separated.
EXTRA_DIRS = [d for d in os.environ.get('EXTRA_LIB_DIRS', '').split(':') if d]


@lru_cache(maxsize=None)
def locate(name, lib):
    dirs = [os.path.join(OUT, d) for d in vendor_dirs(lib) + [x.format(lib=lib) for x in LLNDK_DIRS]]
    dirs += [d.format(lib=lib) for d in EXTRA_DIRS]
    for d in dirs:
        p = os.path.join(d, name)
        if os.path.exists(p):
            return os.path.realpath(p)
    return None


def closure(path, lib):
    seen, missing, todo = [], [], list(needed(path))
    names = set()
    while todo:
        n = todo.pop(0)
        if n in names:
            continue
        names.add(n)
        if n in SKIP_LIBS:
            continue
        p = locate(n, lib)
        if p is None:
            missing.append(n)
            continue
        seen.append(p)
        todo.extend(needed(p))
    return seen, missing


@lru_cache(maxsize=None)
def bionic_syms(lib):
    """Exported symbols of the runtime APEX bionic (libc/libm/libdl)."""
    syms = set()
    for mod in ('libc', 'libm', 'libdl'):
        p = os.path.join(os.environ.get('BIONIC_DIR', os.path.join(OUT, 'symbols/apex/com.android.runtime/{lib}/bionic')).format(lib=lib), mod + '.so')
        if not os.path.exists(p):
            sys.exit(f'{p} missing; build the system image first')
        syms |= defined(p)
    return frozenset(syms)


def main():
    results = []
    for root, _, files in os.walk(os.path.join(OUT, 'vendor')):
        for f in files:
            p = os.path.join(root, f)
            if os.path.islink(p) or not is_elf(p):
                continue
            lib = elf_class(p)
            deps, missing = closure(p, lib)
            have = set(defined(p)) | bionic_syms(lib)
            for d in deps:
                have |= defined(d)
            unresolved = sorted(s for s in undefined(p) - have)
            # bionic symbols are not checked
            if missing or unresolved:
                results.append((os.path.relpath(p, OUT), missing, unresolved))
    for rel, missing, unresolved in sorted(results):
        print(rel)
        if missing:
            print('  missing libs:', ' '.join(missing))
        if unresolved:
            print(f'  {len(unresolved)} unresolved:', ' '.join(unresolved[:12]),
                  '...' if len(unresolved) > 12 else '')
    print(f'{len(results)} ELF files with problems', file=sys.stderr)


if __name__ == '__main__':
    main()
