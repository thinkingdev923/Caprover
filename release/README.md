# Release process

The `release` branch is the only production publishing branch. Normal releases
and hotfixes both enter production through a pull request targeting `release`.
Merging into `master` never publishes a production image.

## Normal release

1. Complete any pending `release` to `master` backmerge.
2. Create a short-lived branch from the desired commit on `master`, for example
   `release-candidate/X.Y.Z`.
3. Update `CAPROVER_VERSION` and `RELEASE_FRONTEND_COMMIT` in
   `release/release.conf`.
4. Add a matching `## [X.Y.Z]` section to `CHANGELOG.md`.
5. Open `Release vX.Y.Z` targeting `release`.
6. Merge the PR after its checks pass.

The resulting push to `release` publishes the production image and creates the
draft GitHub release. After publication succeeds, automation creates a
`backmerge-vX.Y.Z` branch pinned to the published commit, opens its PR against
`master`, and enables auto-merge when possible.

The release branch captures the state of `master` when the candidate branch was
created. Later commits to `master` are left for the next release.

## Hotfix

1. Create a short-lived branch from the current `release` branch.
2. Apply the fix.
3. Update `release/release.conf` and `CHANGELOG.md` as described above.
4. Open `Hotfix vX.Y.Z` targeting `release`.
5. Merge the PR after its checks pass.

This publishes the previous production code plus the hotfix, without including
unreleased work from `master`. The automated backmerge carries the fix and
release metadata into future releases.

## Required repository settings

Protect `release` from direct pushes and require pull requests, approvals, and
the `build`, `check-code-formatting`, `run-lint`, and `validate-release-pr`
checks. Configure the `master` rules to require `build`,
`check-code-formatting`, and `run-lint` for the generated backmerge. Allow
GitHub Actions to create and approve pull requests so the publishing workflow
can open and auto-merge backmerge PRs.

GitHub does not start `pull_request` workflows for a PR created with the
built-in `GITHUB_TOKEN`. The backmerge script creates a branch pinned to the
published commit, then explicitly dispatches the build, format, and lint
workflows against it before enabling auto-merge. Repository rules remain
responsible for waiting for those checks.

## Recovering a partial release

If the image build completed and a later draft-release or backmerge job failed,
use **Re-run failed jobs** on the existing workflow run. This preserves the
successful image job and resumes at the failed stage.

If the versioned Docker image was published but its build job reported failure
or the entire workflow was restarted, do not rebuild that version. Confirm the
published manifest digest against the successful `buildx` output, check out the
exact `GITHUB_SHA` shown in the workflow run, and run the remaining scripts with
a GitHub token:

```bash
export GH_TOKEN="TOKEN_WITH_REPOSITORY_WRITE_ACCESS"
export GITHUB_REPOSITORY=caprover/caprover
export GITHUB_SHA="$(git rev-parse HEAD)"
./release/create-draft-release.sh
./release/create-backmerge-pr.sh
```

If the published image cannot be confirmed as the output of that release
attempt, stop and investigate rather than moving or overwriting the versioned
tag.

The scripts in this directory contain the release logic. The workflows under
`.github/workflows` provide triggers, permissions, and runner setup. Frontend
dependencies are built in a separate job without registry credentials. The
publishing job configures the pinned multi-platform emulator, logs in to Docker
Hub, revalidates the release version, and immediately builds and pushes the
image.
