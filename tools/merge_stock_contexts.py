#!/usr/bin/env python3
"""Append to sepolicy/vendor/*_contexts every stock vendor context line whose
type exists in the final policy and whose path/name spec is not already
defined by the AOSP / LineageOS MediaTek policy (e.g. the Trustonic KeyMint
2.0 service label that sepolicy_vndr lacks)."""
import os, re, sys

stock_dir, out_dir, tmp, top = sys.argv[1:5]
known = set(open(f'{tmp}/all_types.txt').read().split())
for l in open(f'{out_dir}/stock_port.te'):
    m = re.match(r'type (\S+);', l)
    if m:
        known.add(m.group(1))

pairs = {
    'file_contexts': ('vendor_file_contexts', ['system/sepolicy/vendor/file_contexts',
                                               'device/mediatek/sepolicy_vndr', 'device/lineage/sepolicy']),
    'property_contexts': ('vendor_property_contexts', ['system/sepolicy/vendor/property_contexts',
                                                       'device/mediatek/sepolicy_vndr', 'device/lineage/sepolicy']),
    'service_contexts': ('vendor_service_contexts', ['device/mediatek/sepolicy_vndr', 'device/lineage/sepolicy']),
    'hwservice_contexts': ('vendor_hwservice_contexts', ['device/mediatek/sepolicy_vndr', 'device/lineage/sepolicy']),
}


def specs(paths, name):
    out = set()
    for p in paths:
        p = os.path.join(top, p)
        files = [p] if os.path.isfile(p) else [
            os.path.join(r, f) for r, _, fs in os.walk(p) for f in fs if f == name]
        for f in files:
            for l in open(f, errors='replace'):
                l = l.strip()
                if l and not l.startswith('#'):
                    out.add(l.split()[0])
    return out


def spec_types(paths, name):
    out = {}
    for p in paths:
        p = os.path.join(top, p)
        files = [p] if os.path.isfile(p) else [
            os.path.join(r, f) for r, _, fs in os.walk(p) for f in fs if f == name]
        for f in files:
            for l in open(f, errors='replace'):
                l = l.strip()
                m = re.search(r'u:object_r:([^:]+):s0', l)
                if l and not l.startswith('#') and m:
                    out[l.split()[0]] = m.group(1)
    return out


aliases = {}  # stock type -> type the existing policy already uses
for name, (stock_name, ours) in pairs.items():
    have = specs(ours, name)
    ours_types = spec_types(ours, name)
    dst = f'{out_dir}/{name}'
    cur = open(dst).read().splitlines() if os.path.exists(dst) else []
    # Ported lines whose spec the existing policy already labels: keep the
    # existing label, remember the type pair to mirror the stock rules.
    kept = []
    for x in cur:
        m = re.search(r'u:object_r:([^:]+):s0', x)
        if x.strip() and not x.startswith('#') and x.split()[0] in ours_types and m:
            if ours_types[x.split()[0]] != m.group(1):
                aliases[m.group(1)] = ours_types[x.split()[0]]
            continue
        kept.append(x)
    cur = kept
    have |= {l.split()[0] for l in cur if l.strip() and not l.startswith('#')}
    add = []
    for l in open(f'{stock_dir}/{stock_name}'):
        l = l.strip()
        if not l or l.startswith('#'):
            continue
        m = re.search(r'u:object_r:([^:]+):s0', l)
        if not m or m.group(1) not in known or l.split()[0] in have:
            continue
        have.add(l.split()[0])
        add.append(l)
    with open(dst, 'w') as f:
        f.write('\n'.join([x for x in cur if x.strip()] +
                          (['', '# Stock labels not provided by sepolicy_vndr'] if add else []) + add) + '\n')
    print(f'{name}: +{len(add)}')

# Mirror stock allow rules of aliased stock types onto the existing types.
te = f'{out_dir}/stock_port.te'
mirrored = []
for l in open(te):
    if not l.startswith(('allow ', 'allowxperm ')):
        continue
    for st, ot in aliases.items():
        if re.search(r'\b' + re.escape(st) + r'\b', l):
            mirrored.append(re.sub(r'\b' + re.escape(st) + r'\b', ot, l.rstrip()))
if mirrored:
    with open(te, 'a') as f:
        f.write('\n# Stock rules mirrored onto labels sepolicy_vndr already defines\n')
        f.write('\n'.join(sorted(set(mirrored))) + '\n')
print('aliases:', aliases, 'mirrored rules:', len(set(mirrored)))
