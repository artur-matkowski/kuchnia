# How a ticket closes

> Owns: .gitea/workflows/tickets.yaml
> Owns: scripts/check-pr.py
> See:  docs/packaging.md

A closing keyword — `close`, `closes`, `closed`, `fix`, `fixes`, `fixed`, `resolve`,
`resolves`, `resolved`, `reopen`, `reopens`, `reopened` — may exist in exactly one place: the
body of a pull request based on `testing`. Gitea closes the ticket when that pull request
merges. Everywhere else — every commit message, every title, every `main`-bound promotion — a
ticket is named `Refs #N`, and the gate refuses the rest.

```
commit message      Refs #56
PR → testing        Closes #56          the ticket closes here
PR → main           Refs #56            the record of what reached main
```

`Refs #M` also names a related or older ticket the work does not deliver. On a `main`-bound
promotion it is the only form there is.

## Why that one place

Gitea acts on a keyword twice over, and the two do not behave alike.

* In a **commit message**, only on a push to the default branch. A commit saying `Closes #21`
  sits on a branch, and sits on `testing`, doing nothing — and closes #21 the moment it
  reaches `main`.
* In a **pull request title or body**, on merge, whatever the base branch is.

The branch pull request is the only description written by the person who did the work, at
the moment they know whether it is finished. A promotion is a bulk `testing` → `main` push
that carries whatever accumulated; its author enumerates nothing and decides nothing, and
asking them for the close is asking the wrong person. That was the failure: every promotion
answered `Refs`, which is the answer that leaves a ticket open, and no ticket closed for
three days with its work already shipped.

The cost of putting it here is that a ticket closes at the `testing` merge, before `main` has
the work and before a board can. Promotion follows within hours, and that is the trade.

## What the gate refuses

`scripts/check-pr.py`, run by `.gitea/workflows/tickets.yaml` on every pull request. Each
refusal prints the state it found, the line to write verbatim, and the command that puts it
there.

1. A closing keyword in any commit message the pull request adds — it would close the ticket
   again when the commit reaches `main`, weeks after the branch pull request already did.
2. A commit message naming no ticket at all, and not saying `No ticket` on a line of its own.
   Every ticket a branch touches is read out of its commit messages, so a commit naming
   nothing is invisible to both the check below and the promotion that records it.
3. A closing keyword in a title, whatever the base. Gitea reads a title exactly as it reads a
   body, and a title is retyped without ceremony.
4. A closing keyword in the body of a `main`-bound promotion. The ticket is already shut by
   then; `reopen` there would undo it.
5. A ticket named by a commit that a `main`-bound description does not record as `Refs #N`.
6. A ticket named by a commit that a `testing`-bound description neither closes as
   `Closes #N` nor holds open as `Refs #N` **followed by a reason on the same line**. A bare
   `Refs #N` is refused: closing is what a branch pull request is for, so leaving a ticket
   open costs a typed sentence and closing it costs nothing.
7. A `testing`-bound description whose closing keyword names a ticket no commit in the branch
   names — the accident below.
8. A description naming no ticket that does not say `No ticket` on a line of its own.

A promotion whose commits name no ticket needs only that line, so a version bump costs nothing.

## What does not announce itself

**Prose springs the keyword.** Gitea reads `close #36` out of a sentence as readily as out of
a line written to be one. *"It would be wrong to close #36 on this anyway"* — written into a
body to explain why the ticket was being left open — closed #36 on that merge. Refusal 7
catches this on the one base where a keyword is otherwise legitimate, but only because no
commit named #36; a keyword aimed at a ticket the branch really does carry is indistinguishable
from intent. `ticket 36` is how to write it.

**A `fix` type is not a closing keyword, by one character.** The pattern wants `#<number>`
straight after the word, so `fix(app): refuse the video track` and `fix: refuse #42 twice`
both pass, while `fix: #42 the tank chart` is read as a close and refused. Name the ticket in
the body, never at the head of a subject.

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

**The gate reports before it blocks.** Settings → Branches → the rule → Enable Status Check,
with `tickets / gate (pull_request)` as the context, on `main` and on `testing` both. Without
that, the check reports and nothing stops a merge — which is how PR #59 was created and
merged seven seconds later with no gate run at all.
