# The run that builds the package, and the two caches that make it cheap

> Owns: .gitea/workflows/deb.yaml
> Owns: scripts/builder.Dockerfile
> Owns: scripts/build-image.sh
> See:  docs/packaging.md docs/targets.md

Every push to `main` or `testing` and every pull request cross-builds the arm64 `.deb` on
this Gitea's own runner. The two branches publish it; everything else builds it and throws
it away.

## Versions and channels

Branch `main` publishes to component `main`, branch `testing` to component `testing`, and
every other branch builds without publishing. Promotion is a merge.

The version is `1.0.<run number>`, with `~testing` appended on branch `testing`. The run
number is per repository and only climbs, so a testing build always outranks the last main
build; the tilde sorts below everything, so the `1.0.7` that eventually promotes
`1.0.7~testing` outranks it in turn. It has nothing to do with the `VERSION` in
`CMakeLists.txt`.

Publishing needs a `PACKAGE_TOKEN` secret holding a Gitea token with `write:package`. Gitea
authenticates the token and ignores the username beside it, so the workflow sends a
placeholder. Nothing else in the run is authenticated — the checkout clones anonymously and
a board's `apt` reads the registry anonymously, both of which stop working the moment this
repository or the `<REDACTED>` organisation stops being public.

## The builder image

A run starting from `debian:trixie` spends five to fifteen minutes installing 668 packages
before it compiles a line — two complete Qt stacks, because a Qt cross build needs the host
tools and the target libraries both ([targets](docs/targets.md)). A prebuilt image is that
environment already installed, and the runner keeps it cached, so the download happens once
rather than twice a day.

**The image is not named in this repository.** It names a registry and this tree is public,
so the two places that need it read it from the operator: the workflow takes
`vars.BUILDER_IMAGE`, a repository variable, and `scripts/build-deb.sh` and
`scripts/build-image.sh` take `KUCHNIA_BUILDER_IMAGE`. **An unset `BUILDER_IMAGE` is an empty
`image:`, and the job then dies at container start having named no image at all** — the same
0-second failure an unreachable registry gives, with nothing in the log separating the two.
The scripts fail with a sentence instead.

**Nothing rebuilds it.** `scripts/build-image.sh` is run by hand, and **a change to
`debian/control` is what makes it stale**. A stale image does not build the wrong package:
`build-deb.sh` asks `dpkg-checkbuilddeps` before installing anything, so a build dependency
the image lacks is installed during the run and the log says the environment did not satisfy
it. Forgetting costs minutes, never a wrong artifact.

While the image is public the runner pulls it with no credentials. Made private, the job
fails at container start, and the fix is a `credentials:` block — Gitea's container registry,
unlike its Debian one, does check the username beside the token.

`scripts/build-deb.sh` with no arguments runs in this same image, so a developer's build and
CI's are one environment rather than two that resemble each other.

## ccache

The compile is around eight minutes cold, over half of it the thirty-five QML files
`qmlcachegen` turns into C++. ccache removes almost all of that on a tree that has barely
changed, and the whole of the wiring is `/usr/lib/ccache` first on the image's `PATH`:
`dh_auto_configure` names the compiler unqualified, so CMake resolves it onto the symlink.
Neither `CMakeLists.txt` nor `debian/rules` mentions ccache, and a desktop build never sees
it.

**The cache lives outside the job container**, at `/srv/ci-cache/kuchnia` on the runner host,
mounted through `container.options`. A gitea-runner permits no volume by default: the path
must be named in `container.valid_volumes` in the runner's `config.yaml`, and a runner that
does not name it fails the job before its first step. That failure is loud and wanted — an
*empty* `/ccache` is not, because it is indistinguishable from a normal cold build. That is
why the run prints `ccache --show-stats` as a step of its own: a hit rate that never climbs
is the only symptom the cache is not surviving between runs.

## What a run does not do

`concurrency` cancels a run whose ref has been pushed again, because its package was obsolete
before it was built. The clone is a plain `git clone` rather than `actions/checkout`: the
container carries no node, and the runner would fetch the action from github.com.
