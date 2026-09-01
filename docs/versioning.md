# The version, and the commit messages it is folded from

> Owns: external-overrides/00-policy.conf
> Owns: .gitea/workflows/commits.yaml
> Owns: .gitea/workflows/release.yaml
> See:  docs/delivery.md docs/ci.md docs/packaging.md

The version is folded out of the commit messages by `versioner`, a git submodule at
`./versioner`; its contract is `versioner/AGENTS.md`. **Nothing inside it is ever edited**:
the policy set here is `external-overrides/00-policy.conf`, and `versioner config` prints what
is in effect and where each key came from.

`production_branches=main` is the branch that prints a bare `X.Y.Z`. It is one fact in three
files - that policy, and the branch filters in `.gitea/workflows/deb.yaml` and
`.gitea/workflows/release.yaml`. Disagree, and a `main` build quietly carries a branch suffix,
or a `testing` build prints a bare number and outranks the promotion it was waiting for.

`refactor`, `perf`, `build` and `revert` are mapped onto a patch beside the shipped `feat`,
`fix` and breaking: each changes the binary a board runs, and a version that does not change
is a package that is never published. `docs`, `style`, `test`, `ci` and `chore` stay `noop`.

## What silently does not bump

**An unknown type is ignored, not rejected.** The fold skips a subject that does not parse and
a type outside the whitelist, and says nothing while it does. `app: lift a label` - this
repository's old grammar - is invisible to the version: the commit ships, the number does not
move, and no package carries it. The `commits` gate is the only thing that refuses it, so a
branch protection rule not requiring `commits / gate (pull_request)` is a version that has
quietly stopped counting - the failure `tickets / gate` has, for the reason
[delivery](docs/delivery.md) gives.

**A squash merge makes the pull request's title the commit subject.** A title is retyped
without ceremony and nothing lints it, so a squash whose title is not conventional lands a
commit that bumps nothing.

**A fresh clone has no hook.** Git never clones hooks; `./versioner/bin/versioner install`
writes it, and until then the first thing to complain is CI. Run `install`, never `init`:
`init` writes workflow stubs built on `actions/checkout`, which no run here uses
([ci](docs/ci.md)), and would leave a second copy of the gate beside the two workflows above.

## The number a board sees

**The pool is a floor.** `apt` takes the highest version it can see and never reports one it
passed over, so a package numbered at or below what is already published is not an error
anywhere - it is a board that stays where it is. `main` holds `1.0.157` from the run counter
this replaced and `testing` holds `1.0.154~testing`; `deb.yaml` reads the pool before every
upload and answers a version already there by publishing nothing, one below it by failing.

**A native package's version may not contain a hyphen**, so `deb.yaml` maps `-` to `~`. Not
only legality: `~` sorts below everything, keeping `1.1.0~testing.a1b2c3d` under its `1.1.0`.

`release.yaml` turns a push to `main` into `CHANGELOG.md`, a `chore(release): vX.Y.Z` commit
and an annotated tag. It needs `RELEASE_TOKEN` with write access **and** a branch protection
rule that lets it push: that commit is the one thing here arriving outside a pull request.

A desktop build asks the same question ([packaging](docs/packaging.md)), so one made on `main`
prints a bare release number indistinguishable from a board's.
