#!/usr/bin/env python3
"""Port the parts of TCL's stock vendor SELinux policy that the LineageOS
MediaTek policy (device/mediatek/sepolicy_vndr) does not cover.

Input : stock vendor_sepolicy.cil + stock vendor_*_contexts, and the policy the
        LineageOS build produced (vendor/system/system_ext CIL + contexts).
Output: <out>/stock_port.te and <out>/{file,service,hwservice,property}_contexts
        fragments.

A rule is ported when it mentions at least one type that only exists in the
stock policy, and every type/attribute it mentions is known afterwards.
"""
import os
import re
import sys

STOCK = os.environ.get("STOCK_SELINUX", "/home/android/tcltab8attempt2/lineage/stock/vendor/etc/selinux")
OUT_PRODUCT = os.environ.get("OUT_PRODUCT", "/home/android/tb305fu/lineage-22.2/out/target/product/selene_vzw")
VER = os.environ.get("STOCK_VER", "_33_0")


def sexps(text):
    """Yield top-level s-expressions as nested lists of strings."""
    tok = re.findall(r'\(|\)|"[^"]*"|[^\s()]+', text)
    stack = [[]]
    for t in tok:
        if t == "(":
            stack.append([])
        elif t == ")":
            e = stack.pop()
            stack[-1].append(e)
        else:
            stack[-1].append(t)
    return stack[0]


# Stock domains that sepolicy_vndr already provides under another name.
RENAME = {
    "mtk_hal_audio": "hal_audio_default",
    "mtk_hal_audio_exec": "hal_audio_default_exec",
    "mtk_hal_sensors": "hal_sensors_default",
    "mtk_hal_sensors_exec": "hal_sensors_default_exec",
}


def strip(n):
    n = n[: -len(VER)] if isinstance(n, str) and n.endswith(VER) else n
    return RENAME.get(n, n)


def declared(cil_paths):
    types, attrs = set(), set()
    for p in cil_paths:
        if not os.path.exists(p):
            continue
        for e in sexps(open(p).read()):
            if not isinstance(e, list) or not e:
                continue
            if e[0] == "type":
                types.add(strip(e[1]))
            elif e[0] == "typeattribute":
                attrs.add(strip(e[1]))
    return types, attrs


def main(out_dir):
    ours_cil = [
        f"{OUT_PRODUCT}/vendor/etc/selinux/vendor_sepolicy.cil",
        f"{OUT_PRODUCT}/system/etc/selinux/plat_sepolicy.cil",
        f"{OUT_PRODUCT}/system_ext/etc/selinux/system_ext_sepolicy.cil",
        f"{OUT_PRODUCT}/vendor/etc/selinux/plat_pub_versioned.cil",
    ]
    our_types = set(open(os.environ.get("PORT_TMP", "/tmp") + "/all_types.txt").read().split())
    our_attrs = set(open(os.environ.get("PORT_TMP", "/tmp") + "/all_attrs.txt").read().split())
    stock = sexps(open(f"{STOCK}/vendor_sepolicy.cil").read())
    st_types, st_attrs = declared([f"{STOCK}/vendor_sepolicy.cil"])

    EXCLUDE = ()
    new_types = sorted(t for t in st_types - our_types - our_attrs if t not in RENAME.values())
    # Attributes the stock vendor policy populates but which were declared on
    # the stock (MediaTek) system side -- LineageOS does not declare them.
    populated = set()
    for e in stock:
        if isinstance(e, list) and len(e) > 2 and e[0] == "typeattributeset":
            populated.add(strip(e[1]))
    undeclared = {a for a in populated - st_attrs - st_types if not a.startswith("base_typeattr_")}
    new_attrs = sorted(a for a in (st_attrs | undeclared) - our_attrs - our_types
                       if not a.startswith("base_typeattr_"))
    new = set(new_types) | set(new_attrs)
    visible = set(open(os.environ.get("PORT_TMP", "/tmp") + "/vis_types.txt").read().split())
    known = {n for n in (visible | new) if not n.startswith("base_typeattr_") and not n.startswith(EXCLUDE)} | {"self"}

    # Stock attribute membership (after version stripping), used to expand the
    # generated base_typeattr_N expressions ("domain minus X") into explicit sets.
    members = {}
    exprs = {}
    for e in stock:
        if isinstance(e, list) and e and e[0] == "typeattributeset":
            name = strip(e[1])
            body = e[2]
            if isinstance(body, list) and body and body[0] in ("and", "or", "not", "all"):
                exprs[name] = body
            elif isinstance(body, list):
                members.setdefault(name, set()).update(strip(m) for m in body)

    def expand(x, depth=0):
        """Set of concrete type names for a type/attribute/expression."""
        if depth > 40:
            return set()
        if isinstance(x, list):
            if not x:
                return set()
            op = x[0]
            if op == "and":
                sets = [expand(a, depth + 1) for a in x[1:]]
                return set.intersection(*sets) if sets else set()
            if op == "or":
                return set().union(*[expand(a, depth + 1) for a in x[1:]])
            if op == "not":
                return ("NOT", frozenset(expand(x[1], depth + 1)))
            # plain list of names
            out = set()
            for a in x:
                r = expand(a, depth + 1)
                out |= r if isinstance(r, set) else set()
            return out
        x = strip(x)
        if x in exprs:
            return expand_expr(exprs[x], depth + 1)
        if x in members:
            out = set()
            for m in members[x]:
                out |= expand(m, depth + 1)
            return out
        return {x}

    def expand_expr(body, depth):
        op = body[0]
        if op == "and":
            pos, neg = None, set()
            for a in body[1:]:
                if isinstance(a, list) and a and a[0] == "not":
                    neg |= expand(a[1], depth + 1)
                else:
                    r = expand(a, depth + 1)
                    pos = r if pos is None else (pos & r)
            return (pos or set()) - neg
        if op == "or":
            return set().union(*[expand(a, depth + 1) for a in body[1:]])
        return set()

    base_attrs = {}
    # (source, target:class) pairs that violate neverallows once expanded.
    ban = set()
    if os.path.exists(os.environ.get("PORT_TMP", "/tmp") + "/ban.txt"):
        for l in open(os.environ.get("PORT_TMP", "/tmp") + "/ban.txt"):
            p = l.split()
            if len(p) == 2:
                ban.add((p[0], p[1]))

    rule_ban = set()
    if os.path.exists(os.environ.get("PORT_TMP", "/tmp") + "/rule_ban.txt"):
        for l in open(os.environ.get("PORT_TMP", "/tmp") + "/rule_ban.txt"):
            p = l.split()
            if len(p) == 3:
                rule_ban.add(tuple(p))

    def te_set(name, extra_neg=()):
        """TE type-set for a stock base_typeattr expression, or None."""
        body = exprs.get(name)
        if body is None:
            return None
        def names(lst):
            return [strip(x) for x in lst if isinstance(x, str)]
        if body[0] == "and" and len(body) == 3 and isinstance(body[2], list) and body[2][0] == "not":
            pos = [x for x in names(body[1]) if x in known]
            neg = [x for x in names(body[2][1]) if x in known]
        elif body[0] == "not":
            pos, neg = ["domain"] if False else [], [x for x in names(body[1]) if x in known]
            if not pos:
                return None
        else:
            return None
        if not pos:
            return None
        neg = set(neg) | set(extra_neg)
        # Newer policies split isolated_app; exclude all isolated app domains.
        if "isolated_app" in neg and "isolated_app_all" in known:
            neg = (neg - {"isolated_app"}) | {"isolated_app_all"}
        neg = sorted(neg)
        return "{ " + " ".join(pos + ["-" + n for n in neg]) + " }"

    def resolve(n):
        n = strip(n)
        if n.startswith("base_typeattr_"):
            return te_set(n)
        return n

    def resolve_for(n, t, c):
        n = strip(n)
        if not n.startswith("base_typeattr_"):
            return n
        if (n, t, c) in rule_ban:
            return None
        extra = [m for (m, tc) in ban if tc == f"{t}:{c}"]
        return te_set(n, extra)

    lines, skipped = [], 0
    attr_members = []
    for e in stock:
        if not isinstance(e, list) or not e:
            continue
        kw = e[0]
        if kw == "typeattributeset" and isinstance(e[2], list) and e[2] and e[2][0] not in ("and", "or", "not", "all"):
            attr = strip(e[1])
            if attr.startswith("base_typeattr_") or attr not in known:
                continue
            for raw in e[2]:
                m = strip(raw)
                was_renamed = isinstance(raw, str) and raw.replace(VER, "") in RENAME
                if was_renamed and attr in known:
                    attr_members.append(f"typeattribute {m} {attr};")
                elif m in new_types:
                    attr_members.append(f"typeattribute {m} {attr};")
                elif m in known and attr in new:
                    attr_members.append(f"typeattribute {m} {attr};")
                elif isinstance(raw, str) and not raw.endswith(VER) and m in known and attr in known:
                    # vendor-declared type in an existing attribute (e.g. mlstrustedobject)
                    attr_members.append(f"typeattribute {m} {attr};")
        elif kw in ("allow", "dontaudit", "auditallow"):
            t = resolve(e[2])
            cp = e[3]
            cls = cp[0] if isinstance(cp, list) and cp else ""
            s = resolve_for(e[1], t, cls) if t else None
            if s is None or t is None:
                skipped += 1
                continue

            if (s not in known and not s.startswith("{")) or (t not in known and not t.startswith("{")) or not isinstance(cp, list) or len(cp) != 2 or not isinstance(cp[1], list):
                skipped += 1
                continue
            perms = " ".join(cp[1])
            lines.append(f"{kw} {s} {t}:{cp[0]} {{ {perms} }};")
        elif kw == "allowx":
            s, t, spec = resolve(e[1]), resolve(e[2]), e[3]
            if s is None or t is None:
                skipped += 1
                continue

            if (s not in known and not s.startswith("{")) or (t not in known and not t.startswith("{")):
                skipped += 1
                continue
            op, cls, rng = spec[0], spec[1], spec[2]
            vals = []
            items = rng if isinstance(rng, list) else [rng]
            if items and items[0] in ("range",):
                items = [items]
            for it in items:
                if isinstance(it, list) and it[0] == "range":
                    vals.append(f"{it[1]}-{it[2]}")
                elif isinstance(it, str):
                    vals.append(it)
            lines.append(f"allowxperm {s} {t}:{cls} {op} {{ {' '.join(vals)} }};")
        elif kw == "typetransition":
            args = [strip(a) for a in e[1:]]
            if not any(a in new for a in args):
                continue
            if len(args) == 4:
                s, t, c, r = args
                if s in known and t in known and r in known:
                    lines.append(f"type_transition {s} {t}:{c} {r};")
                    continue
            elif len(args) == 5:
                s, t, c, n, r = args
                if s in known and t in known and r in known:
                    lines.append(f"type_transition {s} {t}:{c} {r} {n};")
                    continue
            skipped += 1
        elif kw == "genfscon":
            ctx = e[3]
            typ = strip(ctx[2]) if isinstance(ctx, list) else None
            if typ in new:
                lines.append(f"genfscon {e[1]} {e[2]} u:object_r:{typ}:s0")

    # Exact output lines that violate neverallows of the target policy.
    drop_file = os.environ.get("PORT_DROP")
    if drop_file and os.path.exists(drop_file):
        drop = {l.strip() for l in open(drop_file) if l.strip() and not l.startswith("#")}
        lines = [l for l in lines if l not in drop]
        attr_members = [l for l in attr_members if l not in drop]

    os.makedirs(out_dir, exist_ok=True)
    genfs = [l for l in lines if l.startswith("genfscon")]
    te = [l for l in lines if not l.startswith("genfscon")]
    with open(f"{out_dir}/stock_port.te", "w") as f:
        f.write("# Ported from the stock TCL vendor policy (see stage2_sepolicy_port.py)\n\n")
        f.write("\n".join(f"attribute {a};" for a in new_attrs) + "\n\n")
        f.write("\n".join(f"type {t};" for t in new_types) + "\n\n")
        f.write("\n".join(sorted(set(attr_members))) + "\n\n")
        f.write("\n")
        f.write("\n".join(te) + "\n")
    with open(f"{out_dir}/genfs_contexts", "w") as f:
        f.write("\n".join(genfs) + "\n")

    # contexts files: take stock lines whose type is new
    for name, stock_file in (("file_contexts", "vendor_file_contexts"),
                             ("service_contexts", "vendor_service_contexts"),
                             ("hwservice_contexts", "vendor_hwservice_contexts"),
                             ("property_contexts", "vendor_property_contexts")):
        out = []
        for l in open(f"{STOCK}/{stock_file}"):
            m = re.search(r"u:object_r:([^:]+):s0", l)
            if m and m.group(1) in new:
                out.append(l.rstrip())
        with open(f"{out_dir}/{name}", "w") as f:
            f.write("\n".join(out) + "\n")
    print(f"new types {len(new_types)}, new attrs {len(new_attrs)}, rules {len(te)}, "
          f"genfs {len(genfs)}, attr members {len(set(attr_members))}, skipped {skipped}")


if __name__ == "__main__":
    main(sys.argv[1])
