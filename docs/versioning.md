# The version, and the commit messages it is folded from

> Owns: external-overrides/00-policy.conf
> Owns: .gitea/workflows/commits.yaml
> See:  docs/delivery.md docs/ci.md docs/packaging.md

`versioner` is a git submodule at `./versioner`. It computes a version by folding a commit's
whole reachable history, oldest first, from `0.0.0`: each Conventional Commit applies the bump
its type maps to, with SemVer reset semantics. No tag is read, so the same commit computes the
same `X.Y.Z` in any checkout. Off `main` the number carries a `-<branch>.<hash>` prerelease
suffix, which sorts *below* the release it will be promoted into.

**Nothing inside the submodule is ever edited.** Policy is set from
`external-overrides/00-policy.conf`, which layers over `versioner/defaults/*.conf`;
`./versioner/bin/versioner config` prints the result and names the file each key came from.
The operational contract is `versioner/AGENTS.md`.

## What silently does not bump

**An unknown type is ignored, not rejected.** The fold skips a subject that does not parse and
skips a type outside the whitelist, and it says nothing while it does. `app: lift a label` -
this repository's old grammar - is invisible to the version: the commit ships, the number does
not move, and the package that would have carried it is never published. The `commits` gate is
the only thing that refuses it, so a branch protection rule that does not require
`commits / gate (pull_request)` is a version that quietly stops counting - the same failure
`tickets / gate` has, for the same reason: [delivery](docs/delivery.md).

**A squash merge makes the pull request's title the commit subject.** The title is retyped
without ceremony and nothing lints it, so a squash whose title is not conventional lands a
commit that bumps nothing.

**A fresh clone has no hook.** Git never clones hooks; `./versioner/bin/versioner install`
writes it, and until it is run the first thing to complain is CI.

**Do not run `versioner init` here.** It writes its own workflow stubs built on
`actions/checkout` and would leave a second copy of this gate beside
`.gitea/workflows/commits.yaml`. This repository clones by hand and runs the same
`versioner/ci/*.sh` the stubs would - [ci](docs/ci.md) says why there is no action in any run
here. `install` writes the hook and nothing else, which is all that is wanted.

## The policy this repository sets

`production_branches=main`, because `main` is what a board's `apt` follows; every other branch
gets the suffix.

The bump map is widened: `refactor`, `perf`, `build` and `revert` bump a patch beside the
shipped `feat`, `fix` and breaking. All four change the binary a board runs, and a version
that does not change is a package that is never published. `docs`, `style`, `test`, `ci` and
`chore` stay at `noop` - none of them reaches a board.
