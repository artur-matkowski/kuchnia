# How a ticket closes

> Owns: .gitea/workflows/tickets.yaml
> Owns: scripts/check-pr.py
> See:  docs/packaging.md

A closing keyword — `close`, `closes`, `closed`, `fix`, `fixes`, `fixed`, `resolve`,
`resolves`, `resolved`, `reopen`, `reopens`, `reopened` — may exist in exactly one place: the
body of a pull request based on `main`. Everywhere else a ticket is named `Refs #N`. Gitea
closes the ticket when that pull request merges, and the gate refuses every other route to it.

## Why that one place

Gitea acts on a keyword twice over, and the two do not behave alike.

* In a **commit message**, only on a push to the default branch. A commit saying `Closes #21`
  sits on a branch, and sits on `testing`, doing nothing — and closes #21 the moment it
  reaches `main`.
* In a **pull request title or body**, on merge, whatever the base branch is. In a
  `testing`-bound pull request that closes the ticket at the `testing` merge, before a board
  can have the work.

The second is the trap, and prose springs it. *"It would be wrong to close #36 on this
anyway"*, written in a `testing`-bound body to explain why the ticket was being left open,
closed #36 on that merge. No wording mentions a keyword safely; `ticket 36` is how to write it.

A `main`-bound description is the only point where a person has decided the work is delivered,
and it can still be corrected at that moment. A `Closes` in a commit needs a history rewrite
to take back.

## What the gate refuses

`scripts/check-pr.py`, run by `.gitea/workflows/tickets.yaml` on every pull request. Each
refusal prints the state it found, the line to write verbatim, and the command that puts it
there.

1. A closing keyword in any commit message the pull request adds.
2. A closing keyword in the title or body of a pull request not based on `main`.
3. A ticket named by a commit that a `main`-bound description does not account for as either
   `Closes #N` or `Refs #N`. The refusal prints the paste-ready list.
4. A ticket named by a description that no commit in the branch names — refusal 3 reads its
   list from commit messages, so a ticket named only in a description is invisible to it.
5. A description naming no ticket that does not say `No ticket` on a line of its own.

A promotion whose commits name no ticket needs only that line, so a version bump costs nothing.

## What does not announce itself

**Two names in two files spell the status context.** Both branch protection rules require
`tickets / gate (pull_request)`, which is `<workflow name> / <job id> (<event>)`. Rename the
workflow or the job and Gitea waits on a context nothing produces: every pull request stays
unmergeable, with no failing check to point at.

**The check re-reads the description from the API**, not from `$GITHUB_EVENT_PATH`. Editing a
description dispatches a run of its own, and a re-run replays the payload its own event
carried — so an event-payload read would judge a description the author has already fixed, and
*Re-run all jobs* would repeat the same refusal for ever.

**The keyword set mirrors Gitea's.** A keyword Gitea acts on and this does not is a ticket
closing from a place nothing refuses. The pattern here is deliberately the wider of the two: a
refusal is visible, a keyword that slips through is silent.

## Requiring it

Settings → Branches → the rule → Enable Status Check, with `tickets / gate (pull_request)` as
the context, on `main` and on `testing` both. Without that, the check reports and nothing stops
a merge.
