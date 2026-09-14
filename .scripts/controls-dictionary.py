#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
"""Writes docs/controls/: one file per control and per part of an application's
structure, and one per tier they inherit.

Members come from the sources by the rule the tests use - a property is a
`setValue(.x`, `set(.x` or `props[.x`, a handler an `addHandler(.x`, named by
the `on...` function that registers it when there is one. An entry's own
members are what its source file declares; an entry sharing its file with
another takes the blocks of its own type, and a part of the structure takes
what SOURCES names - so a file always lists what the code declares. The marks,
notes and realization lines already written in a file are kept: a realization
is recorded by editing its rows, and running this again only adds or removes
members. On the first run the AppKit marks are read from the rows of
docs/platform-contract.md.

    python3 .scripts/controls-dictionary.py
"""
import os
import re
from collections import OrderedDict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCES_DIR = os.path.join(ROOT, "lib/StateUI/Sources")
VIEWS = os.path.join(SOURCES_DIR, "Views")
DOCS = os.path.join(ROOT, "docs")
OUT = os.path.join(DOCS, "controls")
CONTRACT = os.path.join(DOCS, "platform-contract.md")

PLATFORMS = ["AppKit", "UIKit", "GTK 4", "Android Views", "WinUI 3", "Web"]
CONTROLS = [
    "Label", "Button", "TextField", "TextEditor", "SearchField", "Image", "Picker", "DatePicker",
    "TimePicker", "Switch", "CheckBox", "RadioButton", "Slider", "Stepper", "ActivityIndicator",
    "ProgressBar", "ColorBox", "Border", "PositionIndicator", "VStack", "HStack", "Grid",
    "AbsoluteLayout", "ScrollView", "RefreshView", "SwipeView", "Map", "WebView", "TitleBar",
    "Canvas", "Rectangle", "Ellipse", "Line", "Path", "Polygon", "Polyline",
]
# What an application, its windows and its pages are made of.
STRUCTURE = [
    "Scene", "Window", "Page", "NavigationStack", "TabbedView", "SplitView", "ToolbarItem", "Menu", "MenuItem",
]
ENTRIES = CONTROLS + STRUCTURE
# A part of the structure that is not one type's file: each source it draws on, with what it takes
# there - the whole file, one kind of member, or the blocks an anchor opens.
SOURCES = {
    "Scene": [("Views/Scene.swift", "file"), ("Core/Scenes.swift", "handlers")],
    "Window": [("Views/Application.swift", "extension Window"), ("Types/HostEnvironment.swift", "file"),
               ("Core/Scenes.swift", "properties")],
    "Page": [("Views/Application.swift", "static func page(around"), ("Types/PageSession.swift", "file")],
}
# A tier is a protocol an entry inherits members from; a pair X / XProperties is one tier.
TIER_ORDER = [
    "PropertyContainer", "VisualElement", "View", "Layout", "StackBase", "InputView", "Shape",
    "TextElement", "TextStyleElement", "FontElement", "TextAlignmentElement", "LineHeightElement",
    "DecorableTextElement", "PaddingElement", "BorderElement", "ImageElement", "TintElement",
]
PAIRED = {"VisualElement", "View", "Layout", "StackBase", "InputView", "Shape"}
SKIPPED_FILES = {"Bound.swift", "Style.swift", "ViewBuilder.swift"}
# Labels the matrix uses for more than one entry, or for members another entry registers.
GROUPS = {
    "text inputs": ["TextField", "TextEditor", "SearchField"],
    "shapes": ["Rectangle", "Ellipse", "Line", "Path", "Polygon", "Polyline"],
    "stack layouts": ["VStack", "HStack"],
    "layouts": ["Grid", "AbsoluteLayout", "VStack", "HStack"],
    "`ModalStack`": ["Window"],
    "menu items": ["MenuItem"],
    "toolbar items": ["ToolbarItem"],
    "menu / toolbar items": ["MenuItem", "ToolbarItem"],
}
MARKS = {"✅", "✅*"}
LEGEND = ("✅ realized by that host and covered by its tests · ✅* realized and tested, but "
          "incomplete - the note says what is missing · empty: absent, partial and unverified, "
          "or not looked at yet")


def closing(text, i):
    depth = 0
    for j in range(i, len(text)):
        depth += {"{": 1, "}": -1}.get(text[j], 0)
        if depth == 0:
            return j
    raise ValueError("unbalanced braces")


def uncommented(text):
    return "\n".join(l for l in text.split("\n") if not l.lstrip().startswith("//"))


def members_of(body):
    """(properties, handlers) declared in one block - handlers as {event: modifier}."""
    code = uncommented(body)
    props = set(re.findall(r"setValue\(\.(\w+)", code))
    props |= set(re.findall(r"(?<![\w.])set\(\.(\w+)", code))
    props |= set(re.findall(r"props\[\.(\w+)\]", code))
    handlers = {event: "" for event in re.findall(r"addHandler\(\.(\w+)", code)}
    funcs = [(m.start(), m.group(1)) for m in re.finditer(r"public func (on\w+)\(", code)]
    for k, (start, name) in enumerate(funcs):
        end = funcs[k + 1][0] if k + 1 < len(funcs) else len(code)
        event = re.search(r"addHandler\(\.(\w+)", code[start:end])
        if event:
            handlers[event.group(1)] = name
    return props, handlers


def taken(relative, part):
    """(properties, handlers) an entry takes from one source under lib/StateUI/Sources."""
    text = open(os.path.join(SOURCES_DIR, relative), encoding="utf-8").read()
    if part in ("file", "properties", "handlers"):
        props, handlers = members_of(text)
        return (props if part != "handlers" else set()), (handlers if part != "properties" else {})
    props, handlers = set(), {}
    code = uncommented(text)
    for m in re.finditer(re.escape(part) + r"\b", code):
        start = code.index("{", m.end())
        p, h = members_of(code[start:closing(code, start)])
        props |= p
        handlers.update(h)
    return props, handlers


def read_sources():
    files = {}
    for name in sorted(os.listdir(VIEWS)):
        if name.endswith(".swift") and name not in SKIPPED_FILES:
            files[name] = open(os.path.join(VIEWS, name), encoding="utf-8").read()
    return files


def first_sentence(doc):
    text = " ".join(l.strip()[3:].strip() for l in doc.strip().split("\n") if l.strip().startswith("///"))
    return re.split(r"(?<=[.!?])\s", text, maxsplit=1)[0] if text else ""


def model():
    files = read_sources()
    parents, protocol_docs, protocol_files = {}, {}, {}
    structs = {}
    for name, text in files.items():
        for m in re.finditer(r"((?:^///[^\n]*\n)*)^public protocol (\w+)(?:\s*:\s*([^{\n]+))?", text, flags=re.M):
            listed = (m.group(3) or "").split(" where ")[0]
            parents[m.group(2)] = [p.strip() for p in listed.split(",") if p.strip()]
            protocol_docs[m.group(2)] = first_sentence(m.group(1))
            protocol_files[m.group(2)] = name
        for m in re.finditer(r"((?:^///[^\n]*\n)*)^public struct (\w+)\b[^:{]*:\s*([^{]+)\{", text, flags=re.M):
            structs[m.group(2)] = (name, [p.strip() for p in " ".join(m.group(3).split()).split(",") if p.strip()],
                                   first_sentence(m.group(1)))
    # every block - a struct's body and every extension - owned by its type
    owned = {}
    for name, text in files.items():
        for m in re.finditer(r"^(?:public )?(?:extension|struct) (\w+)[^{]*\{", text, flags=re.M):
            start = text.index("{", m.start())
            props, handlers = members_of(text[start:closing(text, start)])
            entry = owned.setdefault(m.group(1), {"props": set(), "handlers": {}, "files": set()})
            entry["props"] |= props
            entry["handlers"].update(handlers)
            if props or handlers:
                entry["files"].add(name)

    def tier_of(protocol):
        if protocol.endswith("Properties") and protocol[:-len("Properties")] in PAIRED:
            return protocol[:-len("Properties")]
        return protocol

    tiers = OrderedDict()
    for protocol in sorted(parents):
        tier = tier_of(protocol)
        if tier in ENTRIES or (protocol.endswith("Properties") and tier not in PAIRED):
            continue  # an entry of its own, or a control's own Properties
        block = owned.get(protocol, {"props": set(), "handlers": {}, "files": set()})
        t = tiers.setdefault(tier, {"props": set(), "handlers": {}, "files": set(),
                                     "doc": protocol_docs.get(tier, ""), "file": protocol_files.get(tier, "")})
        t["props"] |= block["props"]
        t["handlers"].update(block["handlers"])
        t["files"] |= block["files"]
    tiers = OrderedDict((k, v) for k, v in tiers.items() if v["props"] or v["handlers"])

    def closure(names, seen=None):
        seen = set() if seen is None else seen
        for n in names:
            if n in seen:
                continue
            seen.add(n)
            closure(parents.get(n, []), seen)
        return seen

    sharing = {}
    for c in ENTRIES:
        if c in structs:
            sharing.setdefault(structs[c][0], []).append(c)

    entries = OrderedDict()
    for c in ENTRIES:
        props, handlers = set(), {}
        if c in SOURCES:
            sources = [path for path, _ in SOURCES[c]]
            parts = SOURCES[c]
            conforms, doc = parents.get(c, []), protocol_docs.get(c, "")
        else:
            source, conforms, doc = structs[c]
            sources = ["Views/" + source]
            # a file of its own is the entry's; a shared one, only its type's blocks
            parts = ([(sources[0], "file")] if len(sharing[source]) == 1
                     else [(sources[0], f"struct {c}"), (sources[0], f"extension {c}")])
        for path, part in parts:
            p, h = taken(path, part)
            props |= p
            handlers.update(h)
        inherited = {tier_of(p) for p in closure(conforms) if not p == c + "Properties"}
        inherited = [t for t in TIER_ORDER if t in inherited and t in tiers] + sorted(
            t for t in inherited if t in tiers and t not in TIER_ORDER)
        # a member the entry declares itself is its own, not the tier's
        entries[c] = {"sources": sources, "doc": doc, "own": {"props": props, "handlers": handlers},
                      "tiers": inherited}
    return entries, tiers


def matrix_marks():
    """{(entry or '*', token): {platform: mark}} from the contract's rows."""
    text = open(CONTRACT, encoding="utf-8").read().split("\n")
    marks = {}

    def section(title):
        start = next(i for i, l in enumerate(text) if l.startswith(title))
        end = next(i for i in range(start + 1, len(text)) if text[i].startswith("## "))
        return text[start:end]

    for line in section("## Shared view members"):
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) == 8 and cells[2] in ("✅", "—"):
            for token in re.findall(r"`(\w+)`", cells[1]):
                marks[("*", token)] = {p: ("✅" if cells[2 + k] == "✅" else "") for k, p in enumerate(PLATFORMS)}
    for line in section("## Control properties and handlers"):
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) != 9 or cells[3] not in ("✅", "—"):
            continue
        label = cells[0]
        targets = GROUPS.get(label, [n for n in re.findall(r"`(\w+)`", label) if n in ENTRIES])
        for entry in targets:
            for token in re.findall(r"`(\w+)`", cells[2]):
                marks[(entry, token)] = {p: ("✅" if cells[3 + k] == "✅" else "") for k, p in enumerate(PLATFORMS)}
    return marks


def native_mapping():
    text = open(CONTRACT, encoding="utf-8").read().split("\n")
    start = next(i for i, l in enumerate(text) if l.startswith("## Native control mapping"))
    mapping = {}
    for line in text[start:]:
        if line.startswith("## ") and not line.startswith("## Native control mapping"):
            break
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) == 7 and cells[0].startswith("`"):
            for name in re.findall(r"`(\w+)`", cells[0]):
                mapping[name] = dict(zip(PLATFORMS, cells[1:]))
    return mapping


def existing(path):
    """Rows and realization lines already written, keyed so a regeneration keeps them."""
    rows, realizations = {}, {}
    if not os.path.exists(path):
        return rows, realizations
    section = None
    for line in open(path, encoding="utf-8").read().split("\n"):
        if line.startswith("## "):
            section = line
            continue
        m = re.match(r"\| `(\w+)`(?: \(`(\w+)`\))? \| (\w+) \|(.*)\|\s*$", line)
        if m:
            key = m.group(2) or m.group(1)
            cells = [c.strip() for c in m.group(4).split("|")]
            rows[key] = (cells[:len(PLATFORMS)], cells[len(PLATFORMS)] if len(cells) > len(PLATFORMS) else "")
        elif line.startswith("- **") and section:
            realizations.setdefault(section, []).append(line)
    return rows, realizations


def row(token, handlers, marks, note):
    member = f"`{handlers[token]}` (`{token}`)" if handlers.get(token) else f"`{token}`"
    kind = "handler" if token in handlers else "property"
    return f"| {member} | {kind} | " + " | ".join(marks) + f" | {note} |"


HEADER = ("| Member | Kind | " + " | ".join(PLATFORMS) + " | Notes |\n"
          "| --- | --- | " + " | ".join(":---:" for _ in PLATFORMS) + " | --- |")


def write():
    entries, tiers = model()
    matrix = matrix_marks()
    native = native_mapping()
    os.makedirs(os.path.join(OUT, "tiers"), exist_ok=True)
    summary = OrderedDict()

    for c, info in entries.items():
        path = os.path.join(OUT, f"{c}.md")
        kept, kept_realizations = existing(path)
        counts = {p: [0, 0] for p in PLATFORMS}
        total = 0

        def table(props, handlers, section):
            nonlocal total
            lines = [HEADER]
            for token in sorted(props | set(handlers)):
                if token in kept:
                    marks, note = kept[token]
                    marks = (marks + [""] * len(PLATFORMS))[:len(PLATFORMS)]
                else:
                    shared = matrix.get(("*", token)) if c in CONTROLS else None
                    found = matrix.get((c, token)) or shared or {}
                    marks = [found.get(p, "") for p in PLATFORMS]
                    note = ""
                    if token == "background" and c in CONTROLS and c not in ("Border", "ColorBox"):
                        marks[0] = "✅*"
                        note = "AppKit paints a colour on this view; a brush is drawn only by `Border`."
                total += 1
                for k, p in enumerate(PLATFORMS):
                    if marks[k] == "✅":
                        counts[p][0] += 1
                    elif marks[k] == "✅*":
                        counts[p][1] += 1
                lines.append(row(token, handlers, marks, note))
            return lines

        paths = [f"`lib/StateUI/Sources/{s}`" for s in info["sources"]]
        declared = paths[0] if len(paths) == 1 else ", ".join(paths[:-1]) + " and " + paths[-1]
        inherits = ("Inherits: " + " · ".join(f"[{t}](tiers/{t}.md)" for t in info["tiers"]) if info["tiers"]
                    else "Inherits nothing: every member below is its own.")
        body = [f"# {c}", "", info["doc"], "", inherits, "",
                f"Marks: {LEGEND}. See [the dictionary](README.md).", "",
                f"Declared in {declared}.", ""]
        own_heading = f"## {c}'s own members"
        body += [own_heading, ""]
        if info["own"]["props"] or info["own"]["handlers"]:
            body += table(info["own"]["props"], info["own"]["handlers"], own_heading)
        else:
            body += [f"{c} declares no members of its own; everything it takes comes from the sections below."]
        realized = kept_realizations.get(own_heading) or [
            f"- **{p}**: {native[c][p]}" if c in native and native[c][p] not in ("", "—")
            else f"- **{p}**: no native counterpart is named yet." for p in PLATFORMS]
        body += ["", "Realization:", ""] + realized + [""]
        for t in info["tiers"]:
            heading = f"## From [{t}](tiers/{t}.md)"
            tier = tiers[t]
            props = tier["props"] - info["own"]["props"]
            handlers = {e: n for e, n in tier["handlers"].items() if e not in info["own"]["handlers"]}
            body += [heading, "", tier["doc"], ""] + table(props, handlers, heading) + [""]
            if kept_realizations.get(heading):
                body += ["Realization:", ""] + kept_realizations[heading] + [""]
        open(path, "w", encoding="utf-8").write("\n".join(body).rstrip() + "\n")
        summary[c] = (counts, total)

    for t, tier in tiers.items():
        wearers = [c for c, info in entries.items() if t in info["tiers"]]
        if not wearers:
            raise SystemExit(f"{t} is worn by no entry, so its members would carry no marks: "
                             "add the entry that wears it")
        lines = [f"# {t}", "", tier["doc"], "",
                 f"Declared in `lib/StateUI/Sources/Views/{tier['file']}`." if tier["file"] else "", "",
                 "Worn by: " + " · ".join(f"[{c}](../{c}.md)" for c in wearers), "",
                 "How each of them realizes these members is in its own file.", "",
                 "| Member | Kind |", "| --- | --- |"]
        for token in sorted(tier["props"] | set(tier["handlers"])):
            if token in tier["handlers"] and tier["handlers"][token]:
                lines.append(f"| `{tier['handlers'][token]}` (`{token}`) | handler |")
            elif token in tier["handlers"]:
                lines.append(f"| `{token}` | handler |")
            else:
                lines.append(f"| `{token}` | property |")
        open(os.path.join(OUT, "tiers", f"{t}.md"), "w", encoding="utf-8").write("\n".join(lines).rstrip() + "\n")

    # a file for an entry or a tier the code no longer has goes with it
    for folder, keep in ((OUT, set(entries) | {"README"}), (os.path.join(OUT, "tiers"), set(tiers))):
        for name in os.listdir(folder):
            if name.endswith(".md") and name[:-3] not in keep:
                os.remove(os.path.join(folder, name))

    def summary_table(prefix, names, heading):
        lines = [f"| {heading} | Members | " + " | ".join(PLATFORMS) + " |",
                 "| --- | ---: | " + " | ".join(":---:" for _ in PLATFORMS) + " |"]
        for c in names:
            counts, total = summary[c]
            cells = []
            for p in PLATFORMS:
                done, partial = counts[p]
                cells.append(f"{done} ✅" + (f" · {partial} ✅*" if partial else "") if done or partial else "")
            lines.append(f"| [{c}]({prefix}{c}.md) | {total} | " + " | ".join(cells) + " |")
        return lines

    readme = ["# Control dictionary", "",
              "Every control StateUI ships, and every part an application, its windows and its pages are made "
              "of, member by member, with how far each target host realizes it.", "",
              "An entry's file opens with the members it declares itself, then one section per protocol it "
              "inherits, each linking that protocol's file. Every property and handler carries a mark for each "
              "platform, because a host realizes the same inherited member differently on different controls - "
              "a background is a layer colour on a label and a path fill on a border.", "",
              f"Marks: {LEGEND}.", "",
              "A realization updates its rows in the same change. `ControlDictionaryTests` fails when a file's "
              "members differ from the code, when a ✅* has no note, or when a file is missing; the member lists "
              "are regenerated with `python3 .scripts/controls-dictionary.py`, which keeps every mark, note and "
              "realization line already written.", "",
              "## Controls", ""] + summary_table("", CONTROLS, "Control") + [
              "", "## Application structure", "",
              "The scene, the window and the page an application is made of, the arrangements a page can be, "
              "and the entries of a page's toolbar and menus.", ""] + summary_table("", STRUCTURE, "Part") + [
              "", "## Tiers", ""]
    readme += [f"- [{t}](tiers/{t}.md) - {tiers[t]['doc']}" for t in tiers]
    open(os.path.join(OUT, "README.md"), "w", encoding="utf-8").write("\n".join(readme).rstrip() + "\n")

    contract = open(CONTRACT, encoding="utf-8").read()
    block = ("<!-- dictionary:begin -->\n" + "\n".join(summary_table("controls/", CONTROLS, "Control")) + "\n\n"
             + "\n".join(summary_table("controls/", STRUCTURE, "Part")) + "\n<!-- dictionary:end -->")
    if "<!-- dictionary:begin -->" in contract:
        contract = re.sub(r"<!-- dictionary:begin -->.*?<!-- dictionary:end -->", lambda _: block, contract, flags=re.S)
    else:
        anchor = "## Control properties and handlers\n"
        section = ("## Control dictionary\n\n"
                   "Every control, and every part an application, its windows and its pages are made of, has "
                   "its members in [the control dictionary](controls/README.md): one row per property and "
                   "handler, with a mark per platform. The counts below are taken from its files.\n\n"
                   + block + "\n\n")
        contract = contract.replace(anchor, section + anchor, 1)
    open(CONTRACT, "w", encoding="utf-8").write(contract)
    print(f"{len(CONTROLS)} controls, {len(STRUCTURE)} parts of the structure, {len(tiers)} tiers "
          "written to docs/controls")


if __name__ == "__main__":
    write()
