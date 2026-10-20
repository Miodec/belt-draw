#!/usr/bin/env python3
"""Look up the Factorio runtime API in the docs that ship with the game, for the exact installed version.

Usage: tools/api.py NAME [NAME...]
  tools/api.py LuaEntity.rotate        a method or attribute: parameters in call order, table or positional, returns
  tools/api.py LuaUndoRedoStack        a class: every method and attribute
  tools/api.py on_undo_applied         an event: its fields
  tools/api.py undo_index              anything with this name, across all classes

FACTORIO_DOCS=/path/to/doc-html overrides where the docs are (defaults to the Steam install on macOS).
"""
import json
import os
import sys

DOCS = os.environ.get("FACTORIO_DOCS", os.path.expanduser(
    "~/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/doc-html"))


def type_name(t):
    if isinstance(t, str):
        return t
    kind = t.get("complex_type")
    if kind == "union":
        return " | ".join(type_name(o) for o in t["options"])
    if kind == "array":
        return type_name(t["value"]) + "[]"
    if kind == "literal":
        return json.dumps(t["value"])
    if kind in ("dictionary", "LuaCustomTable"):
        return f"{kind}<{type_name(t['key'])}, {type_name(t['value'])}>"
    if kind == "type":
        return type_name(t["value"])
    return kind or json.dumps(t)[:60]


def first_line(text):
    return (text or "").strip().split("\n")[0][:160]


def show_method(owner, method):
    params = sorted(method.get("parameters", []), key=lambda p: p["order"])
    style = "table" if method.get("format", {}).get("takes_table") else "positional"
    print(f"{owner}.{method['name']}  ({style})  {first_line(method.get('description'))}")
    for p in params:
        optional = "?" if p.get("optional") else ""
        print(f"    {p['name']}{optional}: {type_name(p['type'])}  {first_line(p.get('description'))}")
    for r in method.get("return_values", []):
        print(f"    -> {type_name(r['type'])}  {first_line(r.get('description'))}")


def show_attribute(owner, attribute):
    access = "read" + ("/write" if attribute.get("write_type") else " only")
    kind = type_name(attribute.get("read_type") or attribute.get("write_type") or "?")
    print(f"{owner}.{attribute['name']}: {kind}  ({access})  {first_line(attribute.get('description'))}")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    with open(os.path.join(DOCS, "runtime-api.json")) as f:
        api = json.load(f)
    print(f"Factorio {api.get('application_version')}")
    classes = {c["name"]: c for c in api["classes"]}
    events = {e["name"]: e for e in api["events"]}

    for query in sys.argv[1:]:
        found = False
        owner, _, member = query.partition(".")
        if owner in classes and not member:
            found = True
            for m in classes[owner]["methods"]:
                show_method(owner, m)
            for a in classes[owner]["attributes"]:
                show_attribute(owner, a)
        elif query in events:
            found = True
            print(f"{query}  {first_line(events[query].get('description'))}")
            for p in sorted(events[query]["data"], key=lambda p: p["order"]):
                print(f"    {p['name']}: {type_name(p['type'])}  {first_line(p.get('description'))}")
        else:
            for name, c in classes.items():
                if member and name != owner:
                    continue
                wanted = member or query
                for m in c["methods"]:
                    if m["name"] == wanted or (not member and any(p["name"] == wanted for p in m.get("parameters", []))):
                        show_method(name, m)
                        found = True
                for a in c["attributes"]:
                    if a["name"] == wanted:
                        show_attribute(name, a)
                        found = True
        if not found:
            print(f"{query}: not found")


if __name__ == "__main__":
    main()
