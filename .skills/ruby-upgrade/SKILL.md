---
name: ruby-upgrade
description: >
  Upgrade the Ruby version used by the Emmy Rails app (patch or minor bump, e.g.
  3.4.12 -> 3.4.13). Bumps the version everywhere it is declared, installs it
  locally with rbenv, re-checks the Dockerfile's security-fix OS package pins
  against the new ruby base image, builds the release image, and scans it with
  Trivy before opening a PR. Use when asked to "upgrade ruby", "bump ruby to X",
  or to follow a previous Ruby upgrade commit.
---

# Ruby Upgrade Skill

Reference upgrades:

- `07b200b2` (#2329, upstream `CMS-Enterprise/emmy-app`): 3.4.9 -> 3.4.12. Also
  pruned Dockerfile package pins that the new base image already covered.
- `3519ddc7` (#118): 3.4.12 -> 3.4.13. Four one-line changes; every existing pin
  was still needed.

Read `git show <ref>` for whichever is closest to the bump you are making before
you start. The checklist at the top of `app/Dockerfile` is the canonical summary of
this process; this skill expands on it.

All paths below are relative to the repo root. Run Ruby/Rails commands from `app/`.

---

## 1. Confirm the target version

1. Read the current version: `cat app/.ruby-version`.
2. Confirm the target exists as a Docker base image:
   ```sh
   docker manifest inspect ruby:<NEW> >/dev/null && echo ok
   ```
3. Confirm `ruby-build` knows the version: `rbenv install --list-all | grep -x <NEW>`.
   If not, `brew upgrade ruby-build`.

Create a branch named `upgrade-ruby-<NEW>` from an up-to-date `main`.

## 2. Bump the version (four places)

| File | Change |
|---|---|
| `app/.ruby-version` | `<OLD>` -> `<NEW>` |
| `app/Dockerfile` | `ARG RUBY_VERSION=<NEW>` |
| `app/Gemfile` | `ruby "<NEW>"` |
| `app/Gemfile.lock` | `RUBY VERSION` block -> `ruby <NEW>p<PATCHLEVEL>` |

Don't hand-edit the lockfile line. Install Ruby first (step 3), then let Bundler
write it (step 4) so the patchlevel is correct. Step 4 ends with a check that
all four were updated.

## 3. Install the new Ruby locally

```sh
cd app
eval "$(rbenv init - bash)"
RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl@3) --with-libyaml-dir=$(brew --prefix libyaml)" \
  rbenv install -s          # reads app/.ruby-version
rbenv rehash
ruby -v                     # must print <NEW>
```

If `rbenv` isn't set up, follow the README setup (`brew bundle`, then add the
`rbenv init` / `nodenv init` lines to `~/.zshrc`).

## 4. Reinstall gems and update the lockfile

```sh
cd app
gem install bundler --conservative -v "$(tail -1 Gemfile.lock | tr -d ' ')"
bundle install              # rewrites RUBY VERSION in Gemfile.lock
git diff Gemfile.lock       # expect ONLY the RUBY VERSION line to change
```

The Dockerfile checklist also says to run `bin/update`. Run it, and commit
whatever it changes. If gem versions change beyond the `RUBY VERSION` line, stop
and decide whether those changes belong in this PR.

Now that the lockfile is updated, check that all four declarations have the new
version (expect one match per file):
```sh
cd ..
grep -n '<NEW>' app/.ruby-version app/Dockerfile app/Gemfile app/Gemfile.lock
```

Then look for leftover references to the old version:
```sh
git grep -n '<OLD>' -- ':!CHANGELOG.md' ':!.skills/'
```
Update a match only if it's an active version declaration. Leave historical
references alone, such as release notes or example upgrades in docs.
`CHANGELOG.md` and this skill are excluded because they always contain past
versions.

## 5. Re-check the Dockerfile OS package pins

`app/Dockerfile` installs specific Debian packages on top of the ruby base image to
patch known vulnerabilities. There are two blocks:

- The commented-out "Upgrade packages in base image" block (manual fixes).
- The "Auto-fix: OS package vulnerabilities detected by Trivy and Grype" block
  (managed by CI automation).

A new base image may already ship the patched versions, so those pins can be
removed (07b200b2 did this). It may not, in which case the pins stay (3519ddc7).
Decide from evidence, not by assuming.

For each pinned package, compare the base image's installed version with the apt
candidate:
```sh
docker run --rm ruby:<NEW> bash -c 'apt-get update -qq >/dev/null 2>&1;
  for p in <pkg1> <pkg2> ...; do
    inst=$(dpkg-query -W -f="\${Version}" $p 2>/dev/null || echo none)
    cand=$(apt-cache policy $p | awk "/Candidate/{print \$2}")
    echo "$p installed=$inst candidate=$cand"
  done'
```

- `installed == candidate` → the base image already has the fix, so the pin can
  be removed.
- `installed < candidate` → keep the pin.

Also list what Trivy flags in the base image on its own:
```sh
trivy image -q --pkg-types os --ignore-unfixed --severity HIGH,CRITICAL ruby:<NEW>
```
A package flagged here may already be fixed in the final app image. For example,
`libpq5` gets upgraded as a dependency of `postgresql-client-17`. Step 6 is the
source of truth.

## 6. Build and scan the release image

```sh
cd app
make release-build OPTS="--tag emmy-app:ruby-<NEW>-test"
docker run --rm --entrypoint chromium emmy-app:ruby-<NEW>-test --version   # Dockerfile checklist step 5
```

Confirm the pinned packages are at their patched versions in the built image:
```sh
docker run --rm --platform linux/amd64 --entrypoint dpkg-query \
  emmy-app:ruby-<NEW>-test -W <pinned packages...>
```

Scan it with the same criteria CI uses in
`.github/actions/trivy-image-scan/action.yml`: OS packages only, HIGH and CRITICAL
severity, fixable vulnerabilities only. If that action's settings change, update
this command to match. You are still in `app/`, so the repo-root ignore file is
`../.trivyignore`:
```sh
trivy image -q --platform linux/amd64 --pkg-types os --ignore-unfixed \
  --severity HIGH,CRITICAL --ignorefile ../.trivyignore emmy-app:ruby-<NEW>-test
```
The target is **zero findings**, which is what CI requires to pass. If removing a
pin brings a finding back, restore the pin.

## 7. Run the app and tests

```sh
cd app
bin/rspec
bin/dev     # smoke test: http://localhost:3000 and /launcher/advanced load
```

## 8. Commit and open the PR

- One commit, message: `Upgrade ruby <OLD> -> <NEW>`.
- Fill in `.github/pull_request_template.md`. Under **Changes**, list the four
  files and link the reference upgrade you followed. Under **Context for
  reviewers**, give the pin decision from step 5 with its evidence: which pins
  you kept or removed and why, plus the Trivy result from step 6.
- Don't add a CHANGELOG entry. It is generated at release time.
- Don't merge. Leave the PR for human review.

---

## Possible simplification (not yet adopted)

The version is declared by hand in three files. The `Gemfile` could use
`ruby file: ".ruby-version"` (Bundler 2.4+), which leaves `.ruby-version` and the
Dockerfile `ARG` as the only manual edits. Propose that as its own PR, not as
part of an upgrade.
