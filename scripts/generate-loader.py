#!/usr/bin/env python3
"""Generate selectable loader source blocks from the tested runtime modules.
Darklua removes types through its parser, rather than matching type syntax with regex.
"""
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
MODULES = ("Schema", "Base64", "Codec", "Snapshot", "Template", "Runtime")


def literal(value):
    padding = "="
    while f"]{padding}]" in value:
        padding += "="
    return f"[{padding}[{value}]{padding}]"


def remove_exports(source):
    types = []
    lines = source.splitlines(keepends=True)
    result = []
    index = 0
    while index < len(lines):
        line = lines[index]
        if line.startswith("export type "):
            block = line
            depth = line.count("{") - line.count("}")
            while depth > 0:
                index += 1
                block += lines[index]
                depth += lines[index].count("{") - lines[index].count("}")
            if not block.startswith("export type Data = Schema.Data"):
                types.append(block)
        else:
            result.append(line)
        index += 1
    return "".join(result), types


def const_bindings(source, mutable):
    def replace(match):
        indent, names = match.groups()
        if names == "function":
            return indent + "const function"
        # Retain mutable bindings, including mixed multiple assignments.
        if any(name.strip() in mutable for name in names.split(",")):
            return match.group(0)
        return indent + "const " + names
    return re.sub(r"(?m)^(\s*)local\s+(function|[A-Za-z_]\w*(?:\s*,\s*[A-Za-z_]\w*)*)\b", replace, source)


def main():
    darklua = shutil.which("darklua") or str(Path.home() / ".rokit/bin/darklua")
    sources = {}
    declarations = []
    for name in MODULES:
        path = ROOT / "src/Loader" / ("init.luau" if name == "Runtime" else f"{name}.luau")
        source = path.read_text()
        # The generated module has its own short header. Keep code and inline comments.
        source = re.sub(r"(?m)^\s*--[^\n]*\n", "", source)
        source, types = remove_exports(source)
        declarations.extend(types)
        source = re.sub(r'(?m)^local \w+ = require\("[^"\n]+"\)\n', "", source)
        source = re.sub(r"\bSchema\.(Kind|Field|Section|Effect|Data)\b", r"\1", source)
        if name == "Runtime":
            source = re.sub(r"(?m)^Photon\.(Schema|Codec|Snapshot|Template) = \w+\n", "", source)
        sources[name] = source.strip() + "\n"

    header = "".join(declarations)
    header = re.sub(r"\bSchema\.(Kind|Field|Section|Effect|Data)\b", r"\1", header)
    header = re.sub(r"export type (Kind|Field|Section)\b", r"type \1", header)
    records = {}
    with tempfile.TemporaryDirectory(prefix="photon-loader-") as directory:
        temp = Path(directory)
        config = temp / "darklua.json"
        config.write_text(json.dumps({"rules": ["remove_types"], "generator": "retain_lines"}))
        for name, typed in sources.items():
            input_path, output_path = temp / f"{name}.luau", temp / f"{name}.out.luau"
            input_path.write_text(typed)
            subprocess.run([darklua, "process", str(input_path), str(output_path), "-c", str(config)], check=True, stdout=subprocess.DEVNULL)
            plain = re.sub(r"(?m)^\s*\n", "", output_path.read_text())
            # Conservative name-level analysis: any assignment keeps that name local.
            mutable = set(re.findall(r"(?m)^\s*(\w+)\s*(?:[+*/%^.-])?=", typed))
            variants = {"typedLocal": typed, "plainLocal": plain,
                        "typedConst": const_bindings(typed, mutable),
                        "plainConst": const_bindings(plain, mutable)}
            if name == "Runtime":
                starts = list(re.finditer(r"(?m)^(?:local )?function ([\w.]+)\(", typed))
                function_names = [m.group(1) for m in starts]
                for variant, code in variants.items():
                    matches = list(re.finditer(r"(?m)^(?:(?:local|const) )?function ([\w.]+)\(", code))
                    bootstrap = code[:matches[0].start()]
                    # The configured preset root is declared between helper functions.
                    preset_decl = re.search(r"(?m)^(?:local|const) presetRoot[^\n]*\n", code)
                    if preset_decl:
                        bootstrap += preset_decl.group(0)
                    records.setdefault("Runtime", {})[variant] = bootstrap
                    for match in matches:
                        end = re.search(r"(?m)^end\b[^\n]*\n?", code[match.start():])
                        assert end, match.group(1)
                        block = code[match.start():match.start() + end.end()]
                        key = match.group(1).replace("Photon.", "api:")
                        records.setdefault(key, {})[variant] = block
                assert len(function_names) == len(matches)
            else:
                records[name] = variants

    generated = ["-- @generated by scripts/generate-loader.py. Do not edit.", "return {"]
    generated.append(f"\ttypes = {literal(header)},")
    for name, variants in records.items():
        generated.append(f'\t["{name}"] = {{')
        for variant, code in variants.items():
            generated.append(f"\t\t{variant} = {literal(code)},")
        generated.append("\t},")
    generated.append("}\n")
    destination = ROOT / "src/Generated/LoaderSources.luau"
    destination.parent.mkdir(exist_ok=True)
    content = "\n".join(generated)
    if not destination.exists() or destination.read_text() != content:
        destination.write_text(content)
    print("Generated configurable loader source blocks")


if __name__ == "__main__":
    main()
