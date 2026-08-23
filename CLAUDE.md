# Working agreement

A Qt Quick application that runs fullscreen in the board's desktop session. Three properties
shape almost every decision here, and all three are deliberate:

* **The application is the work.** Qt owns the scene graph, the render loop and the
  compositing. What this repository adds is what the thing *shows* and what it *does*.
  Effort spent on rendering architecture is effort spent in the wrong repository — that is
  `drm-hmi`, and the split is the point of having two.
* **The display is the session's, not this application's.** It picks no QPA platform, sets no
  mode and owns no connector; it asks for the screen and draws. The **qt-hmi-buildroot**
  image is the vertical that owns a display path, and it configures its own.
* **Nothing here knows what Buildroot is.** `CMakeLists.txt` takes its compiler, sysroot and
  flags from whoever calls it. *Image* packaging belongs to the consumer. The Debian package
  under `debian/` is a different thing and does live here: it names this application's own
  runtime dependencies and its unit, and nothing else builds it.

## How this reaches a board

As a `.deb`, published from `main` or `testing` to this Gitea's Debian registry and installed
with `apt` — [docs/packaging.md](docs/packaging.md). The board runs Raspberry Pi OS Desktop,
and what has to be true of its session before anything shows is
[docs/session.md](docs/session.md).

This tree is also a submodule of the **qt-hmi-buildroot** image repository, which builds it into
a Buildroot image. That has one consequence worth stating plainly: a commit here changes
nothing for that image until the submodule pointer is committed *there*. A local build in
that tree picks the edit up immediately and every other checkout will not, which is exactly
the shape of a change that looks applied and is not. So when the work touches the image:
edit and commit here, then bump the pointer there as part of the same piece of work.

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
That rule crosses the repository boundary too: facts about the image, the board, the
Buildroot packaging or the init script live in qt-hmi-buildroot and are referenced from here with
a `qt-hmi-buildroot/` path prefix, never copied.

**Node anatomy.** `# Title`, then a header block, then prose:

```
> Owns: src/qml/Main.qml
> See:  docs/app.md
```

`Owns:` lines are repo-relative paths, one per line. Every path written anywhere in `docs/`
must exist, unless it carries the `qt-hmi-buildroot/` prefix.

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
  5) Every PR body names its ticket. Based on `main`: `Closes #N`. Based on anything else:
     `Refs #N`, because a closing keyword closes the ticket on *that* merge whatever the base
     is, reporting the work done before `main` has it; the `main`-bound PR carries the close.
  6) When reviewing a PR, hand findings over as PR comments — do not fix them yourself.
  7) **Only a human merges a PR.**
  8) Only human review application visuals, anything that requires screenshoting has to be 
     handover for human review. with some description, what is to be tested
  9) qt-hmi should ba always run with '--configpath ./config.conf' to use local config instead of /etc/... one

## Build

```sh
scripts/build.sh host          # a window on this desktop
scripts/build.sh host --run
scripts/build.sh board         # the cross build, into build/board/, against a Buildroot sysroot
scripts/build.sh board --clean

scripts/build-deb.sh           # the arm64 package, into dist/, in a debian:trixie container
```

`scripts/build.sh` takes no toolchain from the environment: copy
`scripts/toolchain.cmake.example` to `scripts/toolchain.cmake` and put this machine's cross
compiler in it once. See [docs/targets.md](docs/targets.md) for the `QT_HOST_PATH` trap.

Qt 6.5 or later, with `Gui`, `Qml` and `Quick`, plus `QtQuick.Shapes` at runtime. Then Poco
(`Foundation`, `Net`, `NetSSL`, `JSON`), `libpqxx` and `paho-mqtt-cpp`. On Debian:

```sh
sudo apt install libpoco-dev libpqxx-dev libpaho-mqttpp-dev libpaho-mqtt-dev
git submodule update --init --recursive        # deps/, built from source
```
