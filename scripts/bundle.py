#!/usr/bin/env python3
"""Bundle Photon modules into one Luau chunk that can run in Studio's command bar or
through the Studio MCP's execute_luau.

    python3 scripts/bundle.py Renderer/Capture Loader > /tmp/photon.luau

The chunk stores each named module in shared.Photon[name] (for example
shared.Photon["Renderer/Capture"]) and returns that table. Modules that need vide
or the plugin object can't be bundled.
"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src")
REQUIRE = re.compile(r'require\("([^"]+)"\)')


def module_id(path):
    rel = os.path.relpath(path, ROOT)[: -len(".luau")]
    return rel[: -len("/init")] if rel.endswith("/init") else rel


def file_for(mid):
    for candidate in (f"{mid}.luau", f"{mid}/init.luau"):
        full = os.path.join(ROOT, candidate)
        if os.path.exists(full):
            return full
    raise SystemExit(f"no module {mid}")


def resolve(path, spec):
    is_init = os.path.basename(path) == "init.luau"
    base = os.path.dirname(path)
    if spec.startswith("@self/"):
        target = os.path.join(base, spec[len("@self/"):])
    else:
        # in an init module, ./ and ../ start from the folder that contains it.
        start = os.path.dirname(base) if is_init else base
        target = os.path.normpath(os.path.join(start, spec))
    return module_id(target + ".luau") if not target.endswith(".luau") else module_id(target)


def collect(mid, seen, order):
    if mid in seen:
        return
    seen.add(mid)
    path = file_for(mid)
    source = open(path).read()
    for spec in REQUIRE.findall(source):
        collect(resolve(path, spec), seen, order)
    source = REQUIRE.sub(lambda m: f'__require("{resolve(path, m.group(1))}")', source)
    # type exports are only allowed at the top level of a module.
    source = re.sub(r"^export type ", "type ", source, flags=re.M)
    order.append((mid, source))


def main():
    seen, order = set(), []
    for mid in sys.argv[1:]:
        collect(mid, seen, order)
    out = ["local __modules, __loaded = {}, {}",
           "local function __require(name)",
           "\tif __loaded[name] == nil then __loaded[name] = __modules[name]() end",
           "\treturn __loaded[name]",
           "end"]
    for mid, source in order:
        out.append(f'__modules["{mid}"] = function()\n{source}\nend')
    out.append("shared.Photon = shared.Photon or {}")
    for mid in sys.argv[1:]:
        out.append(f'shared.Photon["{mid}"] = __require("{mid}")')
    out.append("return shared.Photon")
    print("\n".join(out))


if __name__ == "__main__":
    main()
