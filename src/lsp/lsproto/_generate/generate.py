import json
import sys

def to_camel(s):
    if not s: return s
    return s[0].lower() + s[1:]

def to_pascal(s):
    if not s: return s
    return s[0].upper() + s[1:]

def zig_type(t):
    kind = t.get("kind")
    if kind == "base":
        name = t.get("name")
        if name == "string" or name == "URI" or name == "DocumentUri": return "[]const u8"
        if name == "boolean": return "bool"
        if name == "integer": return "i32"
        if name == "uinteger": return "u32"
        if name == "decimal": return "f64"
        if name == "null" or name == "any" or name == "Any": return "std.json.Value" # any
        return name
    elif kind == "reference":
        name = t.get("name")
        if name == "LSPAny" or name == "any" or name == "Any": return "std.json.Value"
        if name == "LSPObject": return "std.json.ObjectMap"
        if name == "LSPArray": return "[]std.json.Value"
        return to_pascal(name)
    elif kind == "array":
        return "[]" + zig_type(t.get("element"))
    elif kind == "map":
        return "std.json.ObjectMap"
    elif kind == "or":
        items = t.get("items")
        if len(items) == 2 and any(i.get("kind") == "base" and i.get("name") == "null" for i in items):
            non_null = next(i for i in items if not (i.get("kind") == "base" and i.get("name") == "null"))
            return "?" + zig_type(non_null)
        return "std.json.Value"
    elif kind == "stringLiteral": return "[]const u8"
    elif kind == "booleanLiteral": return "bool"
    elif kind == "integerLiteral": return "i32"
    elif kind == "tuple": return "std.json.Value"
    elif kind == "literal": return "std.json.Value"
    return "std.json.Value"

def generate():
    with open("patchedMetaModel.json") as f:
        model = json.load(f)
    
    out = []
    out.append('const std = @import("std");')
    out.append("")
    
    for e in model.get("enumerations", []):
        name = to_pascal(e["name"])
        t = zig_type(e["type"])
        out.append(f"pub const {name} = enum({t}) {{")
        for val in e["values"]:
            val_name = val["name"]
            if val_name == "type": val_name = "type_"
            if val_name == "error": val_name = "error_"
            if val_name == "continue": val_name = "continue_"
            if val_name == "const": val_name = "const_"
            if val_name == "enum": val_name = "enum_"
            if val_name == "struct": val_name = "struct_"
            if val_name == "return": val_name = "return_"
            if val_name == "export": val_name = "export_"
            v = val["value"]
            if isinstance(v, str): v = f'"{v}"'
            out.append(f"    {val_name} = {v},")
        out.append("};")
        out.append("")
    
    for s in model.get("structures", []):
        name = to_pascal(s["name"])
        out.append(f"pub const {name} = struct {{")
        for p in s.get("properties", []):
            pname = p["name"]
            orig_pname = pname
            if pname in ["type", "error", "continue", "const", "enum", "struct", "return", "export"]:
                pname = pname + "_"
            
            t = zig_type(p["type"])
            if p.get("optional"):
                t = "?" + t
            
            out.append(f'    // @json("{orig_pname}")')
            out.append(f"    {pname}: {t},")
        out.append("};")
        out.append("")

    for ta in model.get("typeAliases", []):
        name = to_pascal(ta["name"])
        t = zig_type(ta["type"])
        out.append(f"pub const {name} = {t};")
        out.append("")

    with open("lsp_generated.zig", "w") as f:
        f.write("\n".join(out))

generate()
