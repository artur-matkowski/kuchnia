# Working agreement

A Qt Quick application that runs fullscreen in the board's desktop session. Three properties
shape almost every decision here, and all three are deliberate:

* **The application is the work.** Qt owns the scene graph, the render loop and the
  compositing. What this repository adds is what the thing *shows* and what it *does*.
  Effort spent on rendering architecture is effort spent in the wrong repository — that is
  `drm-hmi`, and the split is the point of having two.
* **The display is the session's, not this application's.** It picks no QPA platform, sets no
  mode and owns no connector; it asks for the screen and draws. Nothing here configures a
  display path, and a change that starts to is a change in the wrong repository.
* **The package is the only delivery.** `debian/` names this application's runtime
  dependencies and its unit, and nothing else builds it. `CMakeLists.txt` takes its compiler
  and flags from whoever calls it, so the tree also builds on any desktop with Qt 6.

## How this reaches a board

As a `.deb`, published from `main` or `testing` to this Gitea's Debian registry and installed
with `apt` — [docs/packaging.md](docs/packaging.md). The board runs Raspberry Pi OS Desktop,
and what has to be true of its session before anything shows is
[docs/session.md](docs/session.md).

## Start here

**Read [docs/INDEX.md](docs/INDEX.md) before reading code.** It is the map. Every doc node
declares the files it owns, so navigation is a link-follow, not a search.

* Find the node that owns a file: `grep -l '^> Owns:.*<basename>' docs/*.md`
* Print the whole code-to-doc map: `grep '^> Owns:' docs/*.md`
* Read code to confirm mechanics, not to discover intent. If the intent behind something
  exists only in the code, the node is incomplete — fix the node.
* If no node owns a file you are about to change, that is a documentation gap. Close it as
  part of the change.

## Writing documentation

**Replace, never annotate.** When a decision or a requirement changes, delete the old text
and write what is true now. Git holds the history; the docs hold the present. Never write
`previously`, `formerly`, `used to be`, `originally`, `superseded`, `as of <date>`, a
`## History` or `## Changelog` section, a dated entry, or a status marker. A reader must
never have to work out which parts of a node are still in force.

**What a node is for.** A node exists so that a session can change the code it owns without
reading all of it, and without breaking something the code does not announce. That is the
whole purpose. A node is not a design record, not a rationale archive, and not a reply to a
review.

**What a node carries**, in this order:

1. Failures that present *silently* — the blank screen, the window that never appears, the
   binding that quietly evaluates to `undefined`. QML is unusually good at these: a typo in
   a property name is not an error, it is a new property.
2. Invariants a caller must honour, and what breaks when one is not.
3. Couplings a `grep` will not reveal: files that must change together, a string written in
   two places, a fact one part assumes about another.
4. Intent, only where it changes what a caller does.

**The bar for a sentence.** A session that did not know it would write code that is wrong
and reports nothing. If the mistake is a compile error or an abort, the compiler is the
documentation — delete the sentence.

**What a node must not carry.** Each of these is something the bar already rejects, named
because it gets written anyway:

* the argument for a decision already made — the constraint is the fact, the case for it is not;
* a comparison to how another project or product solves the same problem;
* a restatement of a signature, a property, or anything the code says plainly;
* a tutorial for anything with Qt documentation;
* "why not X", unless X is what a reader is about to reach for.

**One fact, one home.** If two nodes need the same fact, one owns it and the other links.

**Node anatomy.** `# Title`, then a header block, then prose:

```
> Owns: src/qml/Main.qml
> See:  docs/app.md
```

`Owns:` lines are repo-relative paths, one per line. Every path written anywhere in `docs/`
must exist — `check-docs.sh` has no exemptions.

**Size.** A node caps at 120 lines of prose — the `Owns:`/`See:` block does not count
against it — with `docs/INDEX.md` at 60. The cap is a limit and not a budget:
`check-docs.sh` prints every node's length beside the code it owns, and a node drifting
toward its cap is a node that has started arguing. Genuinely outgrowing one means splitting
into a new node linked from the index, not quietly dropping content.

**Same commit.** A code change that invalidates a node updates that node in the same commit.
A node describing code that no longer exists is worse than no node at all.

Run `docs/check-docs.sh` after touching anything under `docs/`.

## Engineering practices

* **Fail loud.** Never repair a broken path by adding a fallback beside it — a second way to
  get a picture is a first way that can break unnoticed. The same goes for QML: never wrap a
  binding in a guard that turns a missing value into a plausible-looking default.
* **Declarative first.** A screen is QML. C++ enters when QML cannot express the thing at
  all — not because a loop reads more familiarly there. New C++ that draws is a sign the
  work belongs in `drm-hmi`.
* **Do not fight the caller's flags.** A cross-build system passes `CMAKE_CXX_FLAGS` and a
  toolchain file. Nothing here may overwrite either; project flags go on the target.
* **Comment at the point of surprise**, in the file where the surprise lives. The general
  rule belongs in the node; the local gotcha belongs next to the line that causes it.
* **Comments must not outweigh the code they explain.** Every line here is re-read on every
  future task, and prose costs far more tokens per line than code. If something needs that
  much explaining, the explanation belongs in its node and the file keeps a one-line pointer.
* **Do not comment what fails loudly.** A pitfall that announces itself when it is hit costs
  less to debug than to read about. Comments earn their place on *silent* failures.
* **Hardware is the oracle.** A build that succeeds is not a frame on a screen. Nothing is
  "working" until it has rendered on the target. Report what was observed, not what should
  follow.
* **NEVER RUN THE BINARY. An agent does not test; a human does.** Do not launch `kuchnia`,
  not with `scripts/build.sh host --run`, not in the background, not headless, not under
  `xdotool`, `xvfb`, a screenshot tool or any other driver, and not "just to read the log".
  This is not a preference to be weighed against getting a better answer — there is no task
  in this repository that licenses it.

  What an agent does instead, and this is the whole of it: **build**, then **write the test
  scenario down** — the config to run with, the keys to press, and what each step should
  produce — and **hand it to the human**. A claim about runtime behaviour that no human
  observed is not evidence and must not be written into a commit message, a PR, a ticket
  comment or a doc node.
* **Do not overengineer.** Simplicity is value. Design solutions **as simple as they can be,
  and as complicated as they have to be** to get the job done.
* Commits: imperative subject with a scope prefix (`app:`, `qml:`, `build:`, `docs:`). The
  body explains why.
* **Delivery**
  1) Read the ticket from gitea, together with its milestone.
  2) Do not edit a ticket's description; use comments, so the record reads as a conversation.
  3) Every public comment and commit states that it was written by an LLM, and which one, so
     human and AI authorship stay distinguishable.
  4) When solving a ticket, always push to a branch and hand over by creating a PR.
  5) A closing keyword — `closes`, `fixes`, `resolves` — may exist in exactly one place: the
     body of a PR based on `testing`, which is where the ticket closes. Not in a commit, not
     in a title, not in a `main`-bound promotion, and not in prose: *"it would be wrong to
     close #36 on this anyway"* closed #36 on that merge. Everywhere else a ticket is named
     `Refs #N` — in every commit message, and in the promotion that records what reached
     `main`. A ticket a branch advances but does not finish is held open with `Refs #N` and a
     reason on the same line, and a commit or PR carrying no ticket says `No ticket`.
     `tickets / gate` refuses the rest and takes the merge button with it:
     [docs/delivery.md](docs/delivery.md).
  6) When reviewing a PR, hand findings over as PR comments — do not fix them yourself.
  7) **Only a human merges a PR.**
  8) Only human review application visuals, anything that requires screenshoting has to be 
     handover for human review. with some description, what is to be tested
  9) kuchnia should ba always run with '--configpath ./config.conf' to use local config instead of /etc/... one

## Build

```sh
scripts/build.sh host          # a window on this desktop
scripts/build.sh host --clean
scripts/build.sh host --run

scripts/build-deb.sh           # the arm64 package, into dist/, in the published builder image
```

`scripts/build.sh` builds for this machine only. The board's binary is the package, and its
cross build carries no toolchain file of yours — see [docs/targets.md](docs/targets.md) for
the `QT_HOST_PATH` trap.

Qt 6.5 or later, with `Gui`, `Qml` and `Quick`, plus `QtQuick.Shapes` at runtime. Then Poco
(`Foundation`, `Net`, `NetSSL`, `JSON`), `libpqxx` and `paho-mqtt-cpp`. On Debian:

```sh
sudo apt install libpoco-dev libpqxx-dev libpaho-mqttpp-dev libpaho-mqtt-dev
git submodule update --init --recursive        # deps/, built from source
```
