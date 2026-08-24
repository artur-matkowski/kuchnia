#!/usr/bin/env python3
"""Refuse a pull request that closes a ticket in the wrong place, or leaves one unaccounted for.

The rule, and the silent failures behind each refusal, are docs/delivery.md. This file is the
enforcement and the wording a person reads when it fires - every refusal names the state it
found, the line to write verbatim, and the command that puts it there.
"""

import json
import os
import re
import subprocess
import sys
import urllib.request

# Wider than Gitea's own keyword set on purpose: a refusal here is visible, a keyword that
# slips through is a ticket that closes weeks early and says nothing.
CLOSING = re.compile(
    r"(?i)(?<![0-9a-z_/-])(clos(?:e|es|ed|ing)|fix(?:|es|ed|ing)|resolv(?:e|es|ed|ing)"
    r"|reopen(?:|s|ed|ing))\s*:?\s*(?:[\w.-]+/[\w.-]+)?#(\d+)\b"
)
REFS = re.compile(r"(?i)(?<![0-9a-z_/-])refs?\s*:?\s*(?:[\w.-]+/[\w.-]+)?#(\d+)\b")

NO_TICKET = "No ticket"


def git(*args):
    return subprocess.run(("git",) + args, capture_output=True, text=True, check=True).stdout


def api(path):
    server = os.environ["GITHUB_SERVER_URL"].rstrip("/")
    repo = os.environ["GITHUB_REPOSITORY"]
    with urllib.request.urlopen(f"{server}/api/v1/repos/{repo}/{path}", timeout=30) as r:
        return json.load(r)


def pull_number():
    if os.environ.get("PR_NUMBER"):
        return int(os.environ["PR_NUMBER"])
    with open(os.environ["GITHUB_EVENT_PATH"]) as f:
        event = json.load(f)
    return int(event.get("number") or event["pull_request"]["number"])


def commits(base, head):
    """(sha, subject, message) for every commit this pull request adds to base."""
    shas = git("log", "--format=%H", f"{base}..{head}").split()
    return [
        (sha[:7], git("show", "-s", "--format=%s", sha).strip(), git("show", "-s", "--format=%B", sha))
        for sha in shas
    ]


def hits(pattern, text):
    """(line number, line, ticket) for every match, so a refusal can quote what it refuses."""
    found = []
    for number, line in enumerate(text.splitlines(), 1):
        line = line.strip()
        for match in pattern.finditer(line):
            quoted = line if len(line) <= 76 else line[:73] + "..."
            found.append((number, quoted, int(match.group(match.re.groups))))
    return found


def tickets(pattern, text):
    return {t for _, _, t in hits(pattern, text)}


def listed(numbers):
    return ", ".join(f"#{n}" for n in sorted(numbers))


def required(numbers):
    return "\n".join(f"    Refs #{n}" for n in sorted(numbers))


def main():
    number = pull_number()
    # Re-read the description from the API rather than from the event payload: a re-run
    # replays the payload its event carried, which would judge a description already fixed.
    pull = api(f"pulls/{number}")
    base, head = pull["base"]["ref"], pull["head"]["sha"]
    title, body = pull["title"], pull["body"] or ""

    git("fetch", "--quiet", "origin", base, f"refs/pull/{number}/head")
    added = commits(f"origin/{base}", head)
    print(f"tickets: pull request #{number} into {base}, {len(added)} commit(s)")

    blocks = []

    quoted, offending = [], set()
    for sha, subject, message in added:
        for line, text, ticket in hits(CLOSING, message):
            quoted.append(f"  {sha}  {subject}\n           line {line}:  {text}")
            offending.add(ticket)
    if quoted:
        one = len(quoted) == 1
        blocks.append(
            "BLOCKED: a commit message carries a closing keyword.\n\n"
            + "\n".join(quoted)
            + "\n\n"
            + "A closing keyword in a commit closes the ticket the moment the commit reaches\n"
            + "main - outside the promotion's description, and outside this check.\n\n"
            + f"Required: reword {'that commit' if one else 'those commits'} to say\n\n"
            + required(offending)
            + f"\n\n    git rebase -i origin/{base}        (reword)\n"
            + "    git push --force-with-lease"
        )

    if base != "main":
        quoted, offending = [], set()
        for line, text, ticket in hits(CLOSING, title):
            quoted.append(f"  the title:  {text}")
            offending.add(ticket)
        for line, text, ticket in hits(CLOSING, body):
            quoted.append(f"  line {line}:  {text}")
            offending.add(ticket)
        if quoted:
            blocks.append(
                f"BLOCKED: this description carries a closing keyword and its base is '{base}'.\n\n"
                + "\n".join(quoted)
                + "\n\n"
                + "Gitea acts on a closing keyword in a description whatever the base branch is,\n"
                + f"so merging this closes {listed(offending)} before main has the work.\n\n"
                + "Required: name it without a keyword. Either shape is accepted.\n\n"
                + required(offending)
                + "\n"
                + "\n".join(f"    ticket {n}" for n in sorted(offending))
            )

    in_commits = {}
    for sha, subject, message in added:
        for ticket in tickets(REFS, message) | tickets(CLOSING, message):
            in_commits.setdefault(ticket, subject)
    accounted = tickets(REFS, body) | tickets(CLOSING, body)

    missing = []
    if base == "main":
        missing = sorted(t for t in in_commits if t not in accounted)
        if missing:
            blocks.append(
                "BLOCKED: this promotion carries tickets the description does not account for.\n\n"
                + "\n".join(f"  #{t:<4}  {in_commits[t]}" for t in missing)
                + "\n\n"
                + "Required: the description must give every one of them a line.\n\n"
                + "    Closes #N     this promotion finishes it; it closes when this merges\n"
                + "    Refs #N       the work reaches main, the ticket stays open\n\n"
                + "Copy these lines into the description and change 'Refs' to 'Closes' for each\n"
                + "ticket this promotion finishes:\n\n"
                + required(missing)
                + "\n\n"
                + "Editing the description re-runs this check, and so does 'Re-run all jobs'\n"
                + "in the Actions tab - it re-reads the description from the API, not from the\n"
                + "event that dispatched it."
            )
    else:
        unnamed = sorted(tickets(REFS, body) - set(in_commits))
        if unnamed:
            one = len(unnamed) == 1
            blocks.append(
                f"BLOCKED: the description names {listed(unnamed)} and no commit in this branch does.\n\n"
                + "A promotion reads its ticket list from the commit messages it carries, so a\n"
                + "ticket named only here is invisible when this reaches main - nothing will ask\n"
                + "the promotion to account for it, and it will not close.\n\n"
                + f"Required: put {'the line' if one else 'those lines'} in a commit message too, verbatim.\n\n"
                + required(unnamed)
                + f"\n\n    git commit --amend        (or: git rebase -i origin/{base})\n"
                + "    git push --force-with-lease"
            )

    named = any(l.strip().lower() == NO_TICKET.lower() for l in body.splitlines())
    if not accounted and not missing and not named:
        blocks.append(
            "BLOCKED: this description names no ticket.\n\n"
            + "Work no description names is work no promotion can account for, which is how a\n"
            + "ticket stays open with its work already on main.\n\n"
            + "Required: name the ticket in the description, verbatim,\n\n"
            + "    Refs #N\n\n"
            + "or say, on a line of its own, that there is none.\n\n"
            + f"    {NO_TICKET}"
        )

    if blocks:
        for block in blocks:
            print("\n" + block)
        print(f"\ntickets: {len(blocks)} refusal(s). The rule is docs/delivery.md.")
        return 1

    print(f"tickets: the description accounts for {listed(accounted) or NO_TICKET.lower()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
