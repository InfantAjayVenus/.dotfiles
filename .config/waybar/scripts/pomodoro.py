#!/usr/bin/env python3
"""Simple state-file-backed Pomodoro module for Waybar."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from pathlib import Path

WORK_SECONDS = 25 * 60
SHORT_BREAK_SECONDS = 5 * 60
LONG_BREAK_SECONDS = 15 * 60
INTERVALS = 4

PLAY_ICON = "▶"
PAUSE_ICON = "⏸"
WORK_ICON = "󰔟"
BREAK_ICON = "󰅶"

DEFAULT_STATE_NAME = "waybar-pomodoro-state.json"


def state_path() -> Path:
    runtime_dir = os.environ.get("XDG_RUNTIME_DIR")
    candidates = []
    if runtime_dir:
        candidates.append(Path(runtime_dir))
    candidates.append(Path("/tmp"))

    for directory in candidates:
        try:
            directory.mkdir(parents=True, exist_ok=True)
            probe = directory / f".{DEFAULT_STATE_NAME}.probe"
            probe.write_text("ok")
            probe.unlink()
            return directory / DEFAULT_STATE_NAME
        except OSError:
            continue

    # Last resort: current working directory.
    return Path.cwd() / DEFAULT_STATE_NAME


def default_state() -> dict:
    return {
        "phase": "work",
        "running": False,
        "remaining": WORK_SECONDS,
        "work_sessions": 0,
        "completed": 0,
        "updated_at": time.time(),
    }


def atomic_write(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(payload))
    tmp.replace(path)


def load_state() -> dict:
    path = state_path()
    if not path.exists():
        state = default_state()
        atomic_write(path, state)
        return state

    try:
        state = json.loads(path.read_text())
    except (json.JSONDecodeError, OSError):
        state = default_state()
        atomic_write(path, state)
        return state

    merged = default_state()
    merged.update(state)
    return merged


def notify(summary: str, body: str) -> None:
    try:
        subprocess.run(
            ["notify-send", "--app-name=Pomodoro", summary, body],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except FileNotFoundError:
        pass


def phase_duration(phase: str) -> int:
    if phase == "work":
        return WORK_SECONDS
    if phase == "short_break":
        return SHORT_BREAK_SECONDS
    return LONG_BREAK_SECONDS


def phase_label(phase: str) -> str:
    if phase == "work":
        return "Work"
    if phase == "short_break":
        return "Short break"
    return "Long break"


def phase_icon(phase: str, no_work_icons: bool) -> str:
    if no_work_icons:
        return ""
    return WORK_ICON if phase == "work" else BREAK_ICON


def format_remaining(seconds: int) -> str:
    minutes, secs = divmod(max(0, seconds), 60)
    hours, minutes = divmod(minutes, 60)
    if hours:
        return f"{hours:02d}:{minutes:02d}:{secs:02d}"
    return f"{minutes:02d}:{secs:02d}"


def advance_if_needed(state: dict) -> dict:
    if not state["running"]:
        state["updated_at"] = time.time()
        return state

    now = time.time()
    elapsed = int(max(0, now - float(state.get("updated_at", now))))
    if elapsed <= 0:
        return state

    state["remaining"] = max(0, int(state["remaining"]) - elapsed)
    state["updated_at"] = now

    if state["remaining"] > 0:
        return state

    phase = state["phase"]
    state["running"] = False

    if phase == "work":
        state["completed"] += 1
        state["work_sessions"] += 1
        if state["work_sessions"] >= INTERVALS:
            state["phase"] = "long_break"
            state["work_sessions"] = 0
        else:
            state["phase"] = "short_break"
    else:
        state["phase"] = "work"

    state["remaining"] = phase_duration(state["phase"])
    state["updated_at"] = now
    notify("Pomodoro", f"{phase_label(state['phase'])} started")
    return state


def save_state(state: dict) -> None:
    atomic_write(state_path(), state)


def toggle() -> int:
    state = advance_if_needed(load_state())
    state["running"] = not state["running"]
    state["updated_at"] = time.time()
    save_state(state)
    return 0


def reset() -> int:
    save_state(default_state())
    return 0


def classes_for(state: dict) -> list[str]:
    if (
        state["phase"] == "work"
        and not state["running"]
        and state["remaining"] == WORK_SECONDS
        and state["completed"] == 0
        and state["work_sessions"] == 0
    ):
        return ["idle"]

    classes = []
    if not state["running"]:
        classes.append("pause")
    classes.append("work" if state["phase"] == "work" else "break")
    return classes


def tooltip_for(state: dict) -> str:
    completed = int(state["completed"])
    noun = "pomodoro" if completed == 1 else "pomodoros"
    return f"{completed} {noun} completed this session"


def render(no_work_icons: bool) -> str:
    state = advance_if_needed(load_state())
    save_state(state)

    icon = PLAY_ICON if not state["running"] else PAUSE_ICON
    cycle = phase_icon(state["phase"], no_work_icons)
    parts = [icon, format_remaining(int(state["remaining"]))]
    if cycle:
        parts.append(cycle)

    payload = {
        "text": " ".join(part for part in parts if part),
        "tooltip": tooltip_for(state),
        "class": classes_for(state),
        "alt": state["phase"],
    }
    return json.dumps(payload, ensure_ascii=False)


def run_module(no_work_icons: bool) -> int:
    while True:
        print(render(no_work_icons), flush=True)
        time.sleep(1)


def main(argv: list[str]) -> int:
    no_work_icons = False
    operation = None

    for arg in argv[1:]:
        if arg == "--no-work-icons":
            no_work_icons = True
        elif arg in {"toggle", "reset"}:
            operation = arg
        elif arg in {"-h", "--help"}:
            print("usage: pomodoro.py [--no-work-icons] [toggle|reset]")
            return 0

    if operation == "toggle":
        return toggle()
    if operation == "reset":
        return reset()
    return run_module(no_work_icons)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
