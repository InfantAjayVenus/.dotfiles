#!/usr/bin/env python3
"""Searchable Hyprland keybinding helper — pipes formatted bindings to rofi."""

import re
import subprocess
from pathlib import Path

CONFIG = Path.home() / ".config/hypr/hyprland.conf"

DISPATCHER_LABELS = {
    "exec": "",
    "killactive": "kill active window",
    "exit": "exit Hyprland",
    "togglefloating": "toggle floating",
    "fullscreen": "fullscreen",
    "pseudo": "toggle pseudo-tile",
    "togglegroup": "toggle group",
    "changegroupactive": "cycle group tab",
    "movefocus": "move focus",
    "movewindow": "move window",
    "resizeactive": "resize",
    "workspace": "workspace",
    "movetoworkspace": "move to workspace",
    "togglespecialworkspace": "toggle scratchpad",
    "movecurrentworkspacetomonitor": "move workspace to monitor",
    "focusmonitor": "focus monitor",
    "movewindow": "move window",
    "resizewindow": "resize window",
    "layoutmsg": "layout",
    "submap": "submap",
}

MOD_DISPLAY = {
    "SUPER": "Super",
    "CTRL": "Ctrl",
    "SHIFT": "Shift",
    "ALT": "Alt",
    "META": "Meta",
}

SECTION_COMMENTS = {}  # line_no -> comment text


def parse_config(path):
    variables = {}
    bindings = []
    current_comment = None

    lines = path.read_text().splitlines()

    # Collect section comments (lines starting with # before bind blocks)
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith("#"):
            current_comment = stripped.lstrip("#").strip()
            SECTION_COMMENTS[i] = current_comment
        elif stripped.startswith("$") and "=" in stripped:
            m = re.match(r"\$(\w+)\s*=\s*(.+)", stripped)
            if m:
                variables[m.group(1)] = m.group(2).strip().split("#")[0].strip()
        elif re.match(r"binde?[lm]?\s*=", stripped):
            bindings.append((i, stripped, current_comment))

    return variables, bindings


def resolve(text, variables):
    """Expand $VAR references in text."""
    for name, val in sorted(variables.items(), key=lambda x: -len(x[0])):
        text = text.replace(f"${name}", val)
    return text


def format_mods(mods_str):
    parts = [p.strip().upper() for p in mods_str.split() if p.strip()]
    return " + ".join(MOD_DISPLAY.get(p, p.title()) for p in parts)


def format_binding(raw_line, variables):
    # Strip bind type prefix: bind, bindel, bindl, bindm
    m = re.match(r"binde?[lm]?\s*=\s*(.+)", raw_line)
    if not m:
        return None

    parts = [p.strip() for p in m.group(1).split(",", 3)]
    if len(parts) < 3:
        return None

    mods_raw, key, dispatcher, *rest = parts
    params = rest[0] if rest else ""

    # Resolve variables in mods and params
    mods_raw = resolve(mods_raw, variables)
    params = resolve(params, variables)
    key = resolve(key, variables)

    # Format modifier string
    mods_display = format_mods(mods_raw) if mods_raw.strip() else ""
    key_display = key.strip().title()

    combo = f"{mods_display} + {key_display}" if mods_display else key_display

    # Build description
    dispatcher = dispatcher.strip()
    label = DISPATCHER_LABELS.get(dispatcher, dispatcher)

    if dispatcher == "exec":
        # Show the command, stripping full paths to keep it readable
        cmd = re.sub(r"~?/[^\s]*/([^/\s]+)", r"\1", params).strip()
        # Truncate long commands
        desc = cmd[:60] + "…" if len(cmd) > 60 else cmd
    elif dispatcher in ("workspace", "movetoworkspace"):
        desc = f"{label} {params}"
    elif dispatcher == "movefocus":
        dirs = {"l": "←", "r": "→", "u": "↑", "d": "↓"}
        desc = f"{label} {dirs.get(params.strip(), params)}"
    elif dispatcher == "movewindow":
        dirs = {"l": "←", "r": "→", "u": "↑", "d": "↓"}
        desc = f"{label} {dirs.get(params.strip(), params)}"
    elif dispatcher == "submap":
        desc = f"enter submap: {params}"
    elif label:
        desc = f"{label} {params}".strip()
    else:
        desc = f"{dispatcher} {params}".strip()

    return combo, desc


def main():
    variables, bindings = parse_config(CONFIG)

    rows = []
    prev_comment = None

    for lineno, raw, comment in bindings:
        result = format_binding(raw, variables)
        if not result:
            continue
        combo, desc = result

        # Add a section separator when the comment changes
        if comment and comment != prev_comment and not comment.lower().startswith("example"):
            rows.append(f"── {comment} ──")
            prev_comment = comment

        rows.append(f"{combo:<35}  {desc}")

    if not rows:
        print("No bindings found.")
        return

    rofi_input = "\n".join(rows)
    subprocess.run(
        ["rofi", "-dmenu", "-i", "-p", "keybinds", "-theme-str",
         'entry { placeholder: "search…"; } listview { lines: 20; }'],
        input=rofi_input,
        text=True,
    )


if __name__ == "__main__":
    main()
