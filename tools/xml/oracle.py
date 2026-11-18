"""Independent test-only XML oracle. Never imported by production Bend code."""
from __future__ import annotations

from dataclasses import dataclass, field
import re
import xml.parsers.expat as expat


class Rejected(ValueError):
    def __init__(self, category: str, reason: str):
        super().__init__(reason)
        self.category = category
        self.reason = reason


@dataclass
class Node:
    name: str
    attributes: dict[str, str]
    children: list[Node] = field(default_factory=list)
    parts: list[str] = field(default_factory=list)

    @property
    def text(self) -> str:
        return "".join(self.parts)


def reject(category: str, reason: str):
    raise Rejected(category, reason)


def tree(raw: bytes) -> Node:
    """Expat owns XML well-formedness, reference, CDATA and newline semantics."""
    parser = expat.ParserCreate()
    parser.SetParamEntityParsing(expat.XML_PARAM_ENTITY_PARSING_NEVER)
    stack: list[Node] = []
    roots: list[Node] = []

    def start(name, attrs):
        if ":" in name or any(k == "xmlns" or ":" in k for k in attrs):
            reject("unsupported", "namespace")
        node = Node(name, attrs)
        if stack:
            stack[-1].children.append(node)
        else:
            roots.append(node)
        stack.append(node)

    def end(name):
        assert stack and stack[-1].name == name
        stack.pop()

    def text(value):
        if stack:
            stack[-1].parts.append(value)
        elif value.strip(" \t\r\n"):
            reject("xml", "outside-root text")

    def declaration(version, encoding, standalone):
        if version != "1.0" or (encoding is not None and encoding.lower() != "utf-8"):
            reject("unsupported", "XML version or encoding")

    def forbidden(*args):
        reject("unsupported", "DTD/entity/external resolution/PI")

    parser.StartElementHandler = start
    parser.EndElementHandler = end
    parser.CharacterDataHandler = text
    parser.XmlDeclHandler = declaration
    parser.StartDoctypeDeclHandler = forbidden
    parser.EntityDeclHandler = forbidden
    parser.ExternalEntityRefHandler = forbidden
    parser.ProcessingInstructionHandler = forbidden
    try:
        parser.Parse(raw, True)
    except expat.ExpatError as error:
        reject("xml", str(error))
    if len(roots) != 1:
        reject("xml", "one root required")
    return roots[0]


def attributes(node: Node, allowed: set[str], required: set[str] = frozenset()):
    if set(node.attributes) - allowed or required - set(node.attributes):
        reject("schema", f"attributes of {node.name}")


def leaves(node: Node, names: set[str], required: set[str], repeated: set[str] = frozenset()):
    if node.text.strip(" \t\r\n"):
        reject("schema", f"mixed content in {node.name}")
    result: dict[str, list[Node]] = {}
    for child in node.children:
        if child.name not in names:
            reject("unsupported", f"unknown {child.name} in {node.name}")
        found = result.setdefault(child.name, [])
        if found and child.name not in repeated:
            reject("schema", f"duplicate {child.name}")
        found.append(child)
    if required - set(result):
        reject("schema", "missing " + ",".join(sorted(required - set(result))))
    return result


def leaf(node: Node, allowed: set[str] = frozenset()) -> str:
    attributes(node, allowed)
    if node.children:
        reject("schema", f"nested leaf {node.name}")
    return node.text


def decimal(value: str, maximum: int) -> int:
    if not re.fullmatch(r"[0-9]+", value) or len(value) > 16:
        reject("numeric", "decimal spelling")
    result = int(value, 10)
    if result > maximum:
        reject("numeric", "decimal range")
    return result


def classify(edid: str, field: str) -> dict:
    if field == "VMAD":
        return {"kind": "unsupported", "reason": 3}
    if "|" in edid:
        return {"kind": "unsupported", "reason": 2}
    if re.fullmatch(r"\[[0-9A-Fa-f]{8}\]", edid):
        return {"kind": "bracket", "value": int(edid[1:-1], 16)}
    if any(ord(c) < 33 or ord(c) > 126 for c in edid):
        return {"kind": "unsupported", "reason": 1}
    return {"kind": "literal"}


def typed(raw: bytes) -> dict:
    root = tree(raw)
    if root.name != "SSTXMLRessources":
        reject("unsupported", "root")
    attributes(root, set())
    sections = leaves(root, {"Params", "Content"}, {"Params", "Content"})
    params, content = sections["Params"][0], sections["Content"][0]
    attributes(params, set())
    fields = leaves(params, {"Addon", "Source", "Dest", "Version"}, {"Addon", "Source", "Dest", "Version"})
    values = {name: leaf(items[0]) for name, items in fields.items()}
    if values["Version"] != "2":
        reject("schema", "Version=2")
    addon = values["Addon"]
    if (not addon or addon in {".", ".."} or any(c in "/\\" or ord(c) < 32 or ord(c) == 127 for c in addon)):
        reject("schema", "Addon basename")
    if not values["Source"] or not values["Dest"]:
        reject("schema", "language empty")
    if len(addon.encode()) > 1024 or max(len(values[x].encode()) for x in ("Source", "Dest")) > 256:
        reject("resource", "Params field limit")
    if sum(len(v.encode()) for v in values.values()) > 4096:
        reject("resource", "Params text limit")
    attributes(content, set())
    items = leaves(content, {"String"}, set(), {"String"}).get("String", [])
    if len(items) > 200000:
        reject("resource", "entry count")
    output = []
    for number, item in enumerate(items, 1):
        attributes(item, {"List", "Partial", "sID"}, {"List"})
        attrs = item.attributes
        if attrs["List"] not in {"0", "1", "2"} or attrs.get("Partial") not in {None, "1", "2"}:
            reject("numeric", "List/Partial")
        sid = None
        if "sID" in attrs:
            if not re.fullmatch(r"[0-9A-Fa-f]{6,8}", attrs["sID"]):
                reject("numeric", "sID hexadecimal width")
            sid = {"value": int(attrs["sID"], 16), "width": len(attrs["sID"])}
        fields = leaves(item, {"EDID", "REC", "Source", "Dest", "FuzInfo"}, {"EDID", "REC", "Source", "Dest"})
        edid = leaf(fields["EDID"][0])
        if not edid:
            reject("schema", "empty EDID")
        rec = fields["REC"][0]
        record = leaf(rec, {"id", "idMax"})
        if len(record) != 9 or record[4] != ":" or any(ord(c) < 33 or ord(c) > 126 or c == ":" for c in record[:4] + record[5:]):
            reject("schema", "REC signatures")
        occurrence = None
        if bool("id" in rec.attributes) != bool("idMax" in rec.attributes):
            reject("numeric", "id/idMax pair")
        if "id" in rec.attributes:
            index, maximum = (decimal(rec.attributes[x], 65535) for x in ("id", "idMax"))
            if index > maximum:
                reject("numeric", "id exceeds idMax")
            occurrence = {"index": index, "maxIndex": maximum}
        source, dest = leaf(fields["Source"][0]), leaf(fields["Dest"][0])
        total_text = sum(len(v.encode()) for v in attrs.values()) + len(edid.encode()) + len(record.encode()) + len(source.encode()) + len(dest.encode()) + sum(len(v.encode()) for v in rec.attributes.values())
        fuz = None
        if "FuzInfo" in fields:
            info = fields["FuzInfo"][0]
            attributes(info, set())
            f = leaves(info, {"responseId", "Fuz"}, {"responseId", "Fuz"}, {"Fuz"})
            response = leaf(f["responseId"][0])
            response_id = decimal(response, 2147483647)
            paths = [leaf(x) for x in f["Fuz"]]
            if len(paths) > 4096 or any(len(p.encode()) > 4096 for p in paths):
                reject("resource", "Fuz limit")
            total_text += len(response.encode()) + sum(len(p.encode()) for p in paths)
            fuz = {"responseId": response_id, "count": len(paths)}
        if total_text > 1048576:
            reject("resource", "entry text")
        output.append({"number": number, "list": int(attrs["List"]), "partial": {None: 0, "1": 1, "2": 2}[attrs.get("Partial")], "sid": sid, "record": record[:4], "field": record[5:], "occurrence": occurrence, "identity": classify(edid, record[5:]), "edid": edid, "source": source, "dest": dest, "fuz": fuz})
    return {"params": {"addon": addon, "source": values["Source"], "dest": values["Dest"]}, "entries": output}


def result(raw: bytes) -> dict:
    try:
        return {"accepted": True, "value": typed(raw)}
    except Rejected as error:
        return {"accepted": False, "category": error.category, "reason": error.reason}


if __name__ == "__main__":
    import json
    import sys
    from pathlib import Path
    print(json.dumps(result(Path(sys.argv[1]).read_bytes()), ensure_ascii=False, sort_keys=True))
