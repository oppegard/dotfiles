#!/usr/bin/env python3

import argparse
import json
import sys


def parse_numeric(version):
    text = version.strip()
    if len(text) > 1 and text[0] in "vV" and text[1].isdigit():
        text = text[1:]
    parts = []
    current = ""
    for char in text:
        if char.isdigit():
            current += char
            continue
        if char != "." or not current:
            return None
        parts.append(int(current))
        current = ""
    if not current:
        return None
    parts.append(int(current))
    return tuple(parts)


def numeric_gt(old, new):
    left = parse_numeric(old)
    right = parse_numeric(new)
    if left is None or right is None:
        return None
    width = max(len(left), len(right))
    left = left + (0,) * (width - len(left))
    right = right + (0,) * (width - len(right))
    return right > left


def list_is_forward(old, new):
    if not old or len(old) != len(new):
        return None
    saw_newer = False
    for left, right in zip(old, new):
        if left == right:
            continue
        newer = numeric_gt(left, right)
        if newer is None:
            return None
        if not newer:
            return False
        saw_newer = True
    return saw_newer


def update_kind(old, new):
    if len(old) != 1 or len(new) != 1:
        return ""
    left = parse_numeric(old[0])
    right = parse_numeric(new[0])
    if left is None or right is None:
        return ""
    if left[0] != right[0]:
        return "major"
    left_minor = left[1] if len(left) > 1 else 0
    right_minor = right[1] if len(right) > 1 else 0
    if left_minor != right_minor:
        return "minor"
    return "patch"


def index_changes(changes):
    indexed = {}
    for change in changes:
        new = change.get("new_versions") or []
        if not new:
            continue
        indexed[change["name"]] = {
            "backend": change.get("backend"),
            "old": change.get("old_versions") or [],
            "new": new,
        }
    return indexed


def plan_scope(scope, aged, fresh, emergency_tool, age):
    aged_by_name = index_changes(aged)
    fresh_by_name = index_changes(fresh)
    names = list(dict.fromkeys([*aged_by_name, *fresh_by_name]))
    rows = []
    for name in names:
        aged_change = aged_by_name.get(name)
        fresh_change = fresh_by_name.get(name)
        old = (aged_change or fresh_change)["old"]
        backend = (aged_change or fresh_change).get("backend")
        fresh_new = fresh_change["new"] if fresh_change else None
        aged_new = aged_change["new"] if aged_change else None
        adopted = None
        write_age = ""
        if (
            emergency_tool
            and name == emergency_tool
            and fresh_new
            and list_is_forward(old, fresh_new) is True
        ):
            adopted = fresh_new
            write_age = "0s"
        elif aged_new and list_is_forward(old, aged_new) is True:
            adopted = aged_new
            write_age = age
        kept = adopted if adopted else old
        pending = None
        if fresh_new and fresh_new != kept and list_is_forward(kept, fresh_new) is True:
            pending = fresh_new
        if adopted is None and pending is None:
            continue
        compared = adopted or pending or []
        rows.append(
            {
                "scope": scope,
                "name": name,
                "backend": backend,
                "old": old,
                "adopted": adopted or [],
                "pending": pending or [],
                "update": update_kind(old, compared),
                "age": write_age,
            }
        )
    return {"scope": scope, "rows": rows}


def github_repo(backend):
    if not backend:
        return None
    if backend.startswith("github:"):
        repo = backend.split(":", 1)[1]
    elif backend.startswith("packslip:github.com/"):
        repo = backend.removeprefix("packslip:github.com/")
    elif backend.startswith("aqua:"):
        parts = backend.split(":", 1)[1].split("/")
        if len(parts) < 2 or not parts[0] or not parts[1]:
            return None
        repo = f"{parts[0]}/{parts[1]}"
    else:
        return None
    if repo.count("/") != 1:
        return None
    return repo


def code_list(versions):
    return ", ".join(f"`{version}`" for version in versions)


def change_cell(row):
    old = code_list(row["old"])
    if row["adopted"]:
        return f"{old} → {code_list(row['adopted'])}"
    return old


def render(plans, age, emergency_tool):
    rows = [row for plan in plans for row in plan["rows"]]
    adopted = [row for row in rows if row["adopted"]]
    pending = [row for row in rows if row["pending"]]
    if adopted:
        labels = []
        for row in adopted:
            label = f"{row['name']} {row['adopted'][0]}"
            if label not in labels:
                labels.append(label)
        shown = ", ".join(labels[:2])
        extra = f" (+{len(labels) - 2})" if len(labels) > 2 else ""
        title = f"chore(mise): update {shown}{extra}"
    elif pending:
        labels = []
        for row in pending:
            label = f"{row['name']} {row['pending'][0]}"
            if label not in labels:
                labels.append(label)
        shown = ", ".join(labels[:2])
        extra = f" (+{len(labels) - 2})" if len(labels) > 2 else ""
        title = f"chore(mise): pending {shown}{extra}"
    else:
        title = "chore(mise): update tool locks"

    lines = [
        "This PR contains the following updates:",
        "",
        "| Package | Type | Update | Change | Pending | Scope |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    if not rows:
        lines.append("| | | | | | |")
    for row in rows:
        pending_cell = code_list(row["pending"])
        lines.append(
            "| {name} | tools | {update} | {change} | {pending} | {scope} |".format(
                name=row["name"],
                update=row["update"],
                change=change_cell(row),
                pending=pending_cell,
                scope=row["scope"],
            )
        )
    lines.extend(
        [
            "",
            f"The age window is `{age}` (`mise lock --bump --minimum-release-age`).",
            "A pending version is a newer release that this run will not lock.",
            "Mise lock JSON has no pending field.",
            "Pending is the `0s` resolution when that version is newer than the one this PR locks.",
            "",
            "Mise does not refuse a major bump of a `latest` or `lts` request.",
            "A prefix request such as `2` or `1.27` stays inside that prefix.",
            "This job does not add a major filter.",
            "",
            "The updater does not roll a locked version backward when that version is still inside the age window.",
            "MISE_SAFE=1 hides an idiomatic Go pin, so this job does not bump it.",
        ]
    )
    if emergency_tool:
        lines.extend(
            [
                "",
                f"Emergency bump for `{emergency_tool}` uses `--minimum-release-age 0s`.",
            ]
        )
    notes = []
    for row in rows:
        repo = github_repo(row["backend"])
        if repo is None:
            continue
        version = (row["adopted"] or row["pending"] or row["old"])[0]
        state = "pending" if row["pending"] and not row["adopted"] else row["scope"]
        notes.append(
            f"- [{row['name']} {version}](https://github.com/{repo}/releases) ({state})"
        )
    if notes:
        lines.extend(["", "### Release notes", ""])
        lines.extend(notes)
    return title, "\n".join(lines) + "\n"


def read_changes(path):
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, list):
        raise SystemExit(f"{path} must be a JSON array")
    return data


def command_plan(args):
    plan = plan_scope(
        args.scope,
        read_changes(args.aged),
        read_changes(args.fresh),
        args.emergency_tool or "",
        args.age,
    )
    with open(args.out, "w", encoding="utf-8") as handle:
        json.dump(plan, handle)
    for row in plan["rows"]:
        if row["adopted"]:
            print(f"{row['name']} {row['age']}")


def command_render(args):
    plans = []
    for path in args.plan:
        with open(path, encoding="utf-8") as handle:
            plans.append(json.load(handle))
    title, body = render(plans, args.age, args.emergency_tool or "")
    with open(args.title_file, "w", encoding="utf-8") as handle:
        handle.write(title + "\n")
    with open(args.body_file, "w", encoding="utf-8") as handle:
        handle.write(body)


def main(argv):
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)

    plan = sub.add_parser("plan")
    plan.add_argument("--scope", required=True)
    plan.add_argument("--aged", required=True)
    plan.add_argument("--fresh", required=True)
    plan.add_argument("--age", required=True)
    plan.add_argument("--emergency-tool", default="")
    plan.add_argument("--out", required=True)
    plan.set_defaults(func=command_plan)

    render_parser = sub.add_parser("render")
    render_parser.add_argument("--plan", action="append", required=True)
    render_parser.add_argument("--age", required=True)
    render_parser.add_argument("--emergency-tool", default="")
    render_parser.add_argument("--title-file", required=True)
    render_parser.add_argument("--body-file", required=True)
    render_parser.set_defaults(func=command_render)

    args = parser.parse_args(argv)
    args.func(args)


if __name__ == "__main__":
    main(sys.argv[1:])
