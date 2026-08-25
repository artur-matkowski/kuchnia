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
# slips through is a ticket that closes from a place nobody is watching.
CLOSING = re.compile(
    r"(?i)(?<![0-9a-z_/-])(clos(?:e|es|ed|ing)|fix(?:|es|ed|ing)|resolv(?:e|es|ed|ing)"
    r"|reopen(?:|s|ed|ing))\s*:?\s*(?:[\w.-]+/[\w.-]+)?#(\d+)\b"
)
REFS = re.compile(r"(?i)(?<![0-9a-z_/-])refs?\s*:?\s*(?:[\w.-]+/[\w.-]+)?#(\d+)\b")

# What is left of a line after a reference, before deciding whether a reason was written.
# A trailing full stop is not a reason.
TRAILING = re.compile(r"^[\s.,;:)\]}—–-]+")

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
    """(sha, subject, message) for every commit this pull request adds to base.

    --no-merges because a merge commit carries no authored content: it names no ticket and
    there is nothing to ask of it.
    """
    shas = git("log", "--no-merges", "--format=%H", f"{base}..{head}").split()
    return [
        (sha[:7], git("show", "-s", "--format=%s", sha).strip(), git("show", "-s", "--format=%B", sha))
        for sha in shas
    ]


def hits(pattern, text):
    """(line number, line, ticket, what follows it) for every match.

    The fourth element is the rest of the line with trailing punctuation stripped, which is
    how a reason is told from a bare reference.
    """
    found = []
    for number, line in enumerate(text.splitlines(), 1):
        line = line.strip()
        for match in pattern.finditer(line):
            quoted = line if len(line) <= 76 else line[:73] + "..."
            found.append((number, quoted, int(match.group(match.re.groups)), TRAILING.sub("", line[match.end():]).strip()))
    return found


def tickets(pattern, text):
    return {t for _, _, t, _ in hits(pattern, text)}


def says_no_ticket(text):
    return any(l.strip().lower() == NO_TICKET.lower() for l in text.splitlines())


def listed(numbers):
    return ", ".join(f"#{n}" for n in sorted(numbers))


def lines(word, numbers):
    return "\n".join(f"    {word} #{n}" for n in sorted(numbers))


def main():
    number = pull_number()
    # Re-read the description from the API rather than from the event payload: a re-run
    # replays the payload its event carried, which would judge a description already fixed.
    pull = api(f"pulls/{number}")
    base, head = pull["base"]["ref"], pull["head"]["sha"]
    title, body = pull["title"], pull["body"] or ""
    promotion = base == "main"

    git("fetch", "--quiet", "origin", base, f"refs/pull/{number}/head")
    added = commits(f"origin/{base}", head)
    print(f"tickets: pull request #{number} into {base}, {len(added)} commit(s)")

    blocks = []

    # 1. A closing keyword in a commit. Gitea acts on one when the commit reaches the default
    #    branch, which is a second route to a close the branch pull request already made.
    quoted, offending = [], set()
    for sha, subject, message in added:
        for line, text, ticket, _ in hits(CLOSING, message):
            quoted.append(f"  {sha}  {subject}\n           line {line}:  {text}")
            offending.add(ticket)
    if quoted:
        one = len(quoted) == 1
        blocks.append(
            "BLOCKED: a commit message carries a closing keyword.\n\n"
            + "\n".join(quoted)
            + "\n\n"
            + "Gitea acts on a keyword in a commit when it reaches main - a second route to a\n"
            + "close the branch pull request has already made, firing weeks later and outside\n"
            + "this check.\n\n"
            + f"Required: reword {'that commit' if one else 'those commits'} to say\n\n"
            + lines("Refs", offending)
            + f"\n\n    git rebase -i origin/{base}        (reword)\n"
            + "    git push --force-with-lease"
        )

    # 2. A commit that names no ticket. The promotion reads its record from commit messages,
    #    so a commit naming nothing is work that reaches main with no ticket attached.
    silent = [
        (sha, subject)
        for sha, subject, message in added
        if not tickets(REFS, message) and not tickets(CLOSING, message) and not says_no_ticket(message)
    ]
    if silent:
        one = len(silent) == 1
        blocks.append(
            "BLOCKED: a commit message names no ticket.\n\n"
            + "\n".join(f"  {sha}  {subject}" for sha, subject in silent)
            + "\n\n"
            + "Every ticket this branch touches is read out of its commit messages - by the\n"
            + "check below, and by the promotion that later records what reached main. A commit\n"
            + "naming nothing is invisible to both.\n\n"
            + f"Required: name the ticket in {'that message' if one else 'each of those messages'}, verbatim,\n\n"
            + "    Refs #N\n\n"
            + "or say, on a line of its own, that there is none.\n\n"
            + f"    {NO_TICKET}\n\n"
            + f"    git commit --amend        (or: git rebase -i origin/{base})\n"
            + "    git push --force-with-lease"
        )

    # 3. A closing keyword in the title. Gitea reads a title exactly as it reads a body, and a
    #    title is retyped casually; the body is the one place.
    quoted, offending = [], set()
    for line, text, ticket, _ in hits(CLOSING, title):
        quoted.append(f"  the title:  {text}")
        offending.add(ticket)
    if quoted:
        blocks.append(
            "BLOCKED: the title carries a closing keyword.\n\n"
            + "\n".join(quoted)
            + "\n\n"
            + "Gitea acts on a keyword in a title exactly as it does on one in the body, and a\n"
            + "title is retyped without ceremony. The body is the one place.\n\n"
            + f"Required: take {listed(offending)} out of the title, and name it in the description.\n\n"
            + lines("Closes" if not promotion else "Refs", offending)
        )

    in_commits = {}
    for sha, subject, message in added:
        for _, _, ticket, _ in hits(REFS, message) + hits(CLOSING, message):
            in_commits.setdefault(ticket, subject)

    if promotion:
        # 4. A closing keyword in a promotion's description. By here the branch pull request
        #    has already closed the ticket; a keyword is a second route, and `reopen` is one
        #    that undoes the first.
        quoted, offending = [], set()
        for line, text, ticket, _ in hits(CLOSING, body):
            quoted.append(f"  line {line}:  {text}")
            offending.add(ticket)
        if quoted:
            blocks.append(
                "BLOCKED: this promotion's description carries a closing keyword.\n\n"
                + "\n".join(quoted)
                + "\n\n"
                + "A ticket closes when its branch pull request merges into testing, so by here\n"
                + f"{listed(offending)} is already shut. A keyword in a promotion is a second route to\n"
                + "a result the first one produced.\n\n"
                + "Required: name it as the record it is.\n\n"
                + lines("Refs", offending)
            )

        # 5. A promotion that does not record every ticket its commits name.
        unrecorded = sorted(t for t in in_commits if t not in tickets(REFS, body))
        if unrecorded:
            blocks.append(
                "BLOCKED: this promotion carries tickets its description does not record.\n\n"
                + "\n".join(f"  #{t:<4}  {in_commits[t]}" for t in unrecorded)
                + "\n\n"
                + "A promotion's description is the record of what reached main, and a ticket's\n"
                + "timeline gets its link to that moment from here.\n\n"
                + "Required: give every one of them a line.\n\n"
                + lines("Refs", unrecorded)
                + "\n\n"
                + "Editing the description re-runs this check, and so does 'Re-run all jobs'\n"
                + "in the Actions tab - it re-reads the description from the API, not from the\n"
                + "event that dispatched it."
            )
    else:
        # 6. A branch description that does not close the tickets its commits name. This is the
        #    only place a ticket ever closes, so a description that says nothing leaves it open
        #    with its work delivered - which is the whole failure this gate exists for.
        closed = tickets(CLOSING, body)
        reasoned = {t for _, _, t, tail in hits(REFS, body) if tail}
        bare = {t for _, _, t, tail in hits(REFS, body) if not tail}
        unresolved = sorted(t for t in in_commits if t not in closed and t not in reasoned)
        if unresolved:
            blocks.append(
                "BLOCKED: this description does not close the tickets its commits name.\n\n"
                + "\n".join(
                    f"  #{t:<4}  {in_commits[t]}"
                    + ("\n           named 'Refs' with no reason after it" if t in bare else "")
                    for t in unresolved
                )
                + "\n\n"
                + "Gitea closes a ticket named here when this merges into testing, and this\n"
                + "description is the only place that happens. Nothing downstream will close it.\n\n"
                + "Required: give every one of them a line.\n\n"
                + lines("Closes", unresolved)
                + "\n\n"
                + "A ticket this branch advances but does not finish is downgraded by hand, and\n"
                + "must say on the same line why it stays open:\n\n"
                + f"    Refs #{unresolved[0]} - <what is still missing>\n\n"
                + "Editing the description re-runs this check, and so does 'Re-run all jobs'\n"
                + "in the Actions tab - it re-reads the description from the API, not from the\n"
                + "event that dispatched it."
            )

        # 7. A closing keyword in a branch description for a ticket no commit names. This is
        #    the one base where a keyword is not otherwise refused, so it is the one place the
        #    #36 accident can still happen: prose that mentions closing a ticket closes it.
        stray = sorted(closed - set(in_commits))
        if stray:
            one = len(stray) == 1
            blocks.append(
                f"BLOCKED: this description closes {listed(stray)}, which no commit in this branch names.\n\n"
                + "\n".join(
                    f"  line {line}:  {text}"
                    for line, text, ticket, _ in hits(CLOSING, body)
                    if ticket in stray
                )
                + "\n\n"
                + "Gitea reads a keyword out of prose as readily as out of a line written to be\n"
                + f"one, and merging this shuts {listed(stray)} with nothing here having done the work.\n\n"
                + f"Required: if the sentence is prose, say {'it' if one else 'them'} without a keyword.\n\n"
                + "\n".join(f"    ticket {n}" for n in stray)
                + "\n\n"
                + f"If this branch does deliver {'it' if one else 'them'}, name {'it' if one else 'them'} in a commit too.\n\n"
                + lines("Refs", stray)
            )

    # 8. A description that names nothing at all and does not say so. A version bump needs
    #    only that line, so a promotion carrying no ticket costs nothing.
    named = tickets(REFS, body) | tickets(CLOSING, body)
    if not named and not says_no_ticket(body) and not in_commits:
        blocks.append(
            "BLOCKED: this description names no ticket.\n\n"
            + "Work no description names is work nothing can account for later.\n\n"
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

    if promotion:
        print(f"tickets: this promotion records {listed(in_commits) or NO_TICKET.lower()}")
    else:
        closing = tickets(CLOSING, body)
        held = sorted(t for t in in_commits if t not in closing)
        print(
            f"tickets: merging this closes {listed(closing) or 'nothing'}"
            + (f", and holds {listed(held)} open" if held else "")
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
