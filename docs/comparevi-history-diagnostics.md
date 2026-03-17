# CompareVI History Diagnostics

This repository consumes `comparevi-history` as the canonical released VI history platform surface for pull-request
review without running that platform directly from untrusted PR events.

## Workflows

- [`.github/workflows/comparevi-history-pull-request-diagnostics.yml`](../.github/workflows/comparevi-history-pull-request-diagnostics.yml)
  is the standard automatic changed-VI pull-request surface. It stays thin by forwarding the current repository and the
  checked-in `.github/comparevi-history-pr-policy.json` contract into the reusable
  `comparevi-history` execution workflow pinned to the immutable platform commit
  `d0e92af4f36da76c946a194efe4c2cc79590629d`.
- [`.github/workflows/comparevi-history-pull-request-diagnostics-publish.yml`](../.github/workflows/comparevi-history-pull-request-diagnostics-publish.yml)
  is the privileged `workflow_run` follow-on publisher. It reads the execution artifact from the completed pull request
  run and creates or updates the sticky PR comment without checking out or executing candidate PR code.
- [`.github/workflows/comparevi-history-manual-vi-exploration.yml`](../.github/workflows/comparevi-history-manual-vi-exploration.yml)
  is a maintainer-dispatched workflow for exploring one repo-relative `.vi` path on demand through the published
  reusable `comparevi-history` manual exploration workflow. The wrapper stays thin: it forwards `vi_path`, `ref`,
  `compare_modes`, `include_merge_parents`, and `noise_policy`, and pins both the reusable workflow ref and
  `platform_ref` to `v1.3.7`.
- [`.github/workflows/comparevi-history-corpus-evidence-pilot.yml`](../.github/workflows/comparevi-history-corpus-evidence-pilot.yml)
  is a maintainer-dispatched workflow that proves the corpus evidence contracts against the released
  `comparevi-history` platform without adding repo-local corpus logic. It runs the released platform scripts for the
  fixed seed targets:
  - `Tooling/deployment/VIP_Post-Install Custom Action.vi`
  - `Tooling/deployment/VIP_Pre-Install Custom Action.vi`
- [`.github/workflows/comparevi-history-manual-pr-diagnostics.yml`](../.github/workflows/comparevi-history-manual-pr-diagnostics.yml)
  is a maintainer-dispatched workflow for inspecting a specific pull request and checked-in comparevi-history target id
  on demand.
- [`.github/workflows/comparevi-history-comment-gated.yml`](../.github/workflows/comparevi-history-comment-gated.yml)
  is a maintainer-only slash-command workflow that runs when a trusted maintainer comments
  `/comparevi-history <target-id> [--modes attributes,front-panel,block-diagram]` on a pull request.
- [`.github/comparevi-history-pr-policy.json`](../.github/comparevi-history-pr-policy.json) is the repo-owned
  automatic PR policy contract. It selects dynamic raw `.vi` paths, blocks above `10` changed VIs, keeps the explicit
  public mode bundle `attributes`, `front-panel`, and `block-diagram`, and enables the split hosted execution plus
  sticky-comment publisher path for same-repo and fork pull requests.
- [`.github/comparevi-history-targets.json`](../.github/comparevi-history-targets.json) is the repo-owned target
  catalog that declares which VI history targets this consumer exposes.

The automatic changed-VI pull-request surface:

- is additive and leaves the manual PR diagnostics, comment-gated diagnostics, manual exploration, corpus pilot, and
  checked-in target catalog unchanged
- triggers on `pull_request` for `main`, `develop`, `release/*`, `feature/*`, and `hotfix/*`
- discovers changed `.vi` files through `comparevi-history/changed-vi-discovery@v2` using the trusted base-branch
  policy checkout instead of a PR-local script
- aggregates execution state through `comparevi-history/pr-run@v2`
- does not require the touched VI to exist in `.github/comparevi-history-targets.json`
- executes full unsuppressed history evidence for each selected changed VI
- fails closed when more than `10` changed `.vi` files are present in one pull request
- writes one aggregate execution bundle with:
  - `changed-vi-discovery.json`
  - `pr-run.json`
  - `pr-comment.md`
  - `pr-step-summary.md`
  - `index.md`
  - `index.html`
  - per-target `request.json`, `public-run.json`, `shared-evidence.json`, `history-summary.json`, `history-report.md`,
    and `history-report.html`
- uses the execution artifact index as the primary full reviewer surface; the PR comment and workflow summary are
  bounded entrypoints only
- auto-runs for same-repo pull requests with a read-only execution token
- auto-runs for fork pull requests through the same read-only execution path and then publishes the sticky reviewer
  comment from the separate privileged `workflow_run` publisher
- keeps the consumer wrapper thin by delegating changed-file discovery, aggregation, comment preparation, and sticky
  comment publication to `comparevi-history`

The manual exploration workflow:

- pins the immutable reusable workflow
  `LabVIEW-Community-CI-CD/comparevi-history/.github/workflows/manual-vi-exploration.yml@v1.3.7`
- keeps `platform_ref` aligned with the workflow pin at `v1.3.7`
- accepts repo-relative `vi_path` input plus `ref`, `compare_modes`, `include_merge_parents`, and `noise_policy`
- defaults to the trusted raw exploration profile:
  - `compare_modes: full`
  - `noise_policy: include`
- uploads `revision-catalog.json`, `exploration-run.json`, `index.md`, `index.html`, `timeline.md`, `timeline.html`,
  and `manual-vi-exploration-bundle.zip`
- appends the reusable workflow summary to the workflow run
- does not add repo-local history discovery, chunk orchestration, or renderer logic

The corpus evidence pilot workflow:

- pins `LabVIEW-Community-CI-CD/comparevi-history@v1.3.8` by checking out the published platform repository at
  `v1.3.8`
- accepts only `ref` as operator input; the VI target set is fixed for this pilot
- reuses the released platform scripts for:
  - revision catalog discovery
  - chunk planning
  - chunk execution
  - manual exploration aggregation
  - bundle publication
  - corpus aggregation
- writes one deterministic corpus surface for both seed targets in one run:
  - `corpus-index.json`
  - `pages/corpus-page-*.json`
  - `downstream-processing-manifest.json`
  - `corpus-pilot-manifest.json`
- uploads the full pilot results root under
  `tests/results/ref-compare/history-exploration/corpus-pilot`
- fails closed unless both seed targets complete and the corpus index reports deterministic `page-ordinal`
  continuation
- keeps the consumer wrapper thin by delegating the heavy lifting to the released platform instead of copying repo-local
  corpus scripts

The PR diagnostics workflows:

- use released `LabVIEW-Community-CI-CD/comparevi-history` refs only
- pin the immutable release `LabVIEW-Community-CI-CD/comparevi-history@v1.1.0`
- run on `ubuntu-latest`
- pre-pull `nationalinstruments/labview:2026q1-linux` under a repo-level concurrency group so image acquisition and
  compare execution stay serialized
- resolve the PR head repository and SHA dynamically
- check out the trusted base repository to supply `.github/comparevi-history-targets.json` and the hosted invoke adapter
- check out the PR head into a separate path so only the inspected content comes from the untrusted branch or fork
- route requests through the trusted target catalog checkout instead of the PR head checkout
- use only explicit public compare modes: `attributes`, `front-panel`, and `block-diagram`
- use the trusted repo-local `Tooling/Invoke-CompareVIHistoryHostedNILinux.ps1` adapter as a maintainer-controlled
  `invoke_script_path`
- upload diagnostics artifacts
- append the action-owned `public-step-summary-path`
- publish the action-owned `public-comment-path` for comment-gated reviewer flows

The automatic changed-VI PR path and the manual exploration path are additive. Existing target-id PR diagnostics remain
unchanged and continue to use the checked-in target catalog.

## Release Contract

- Consumer workflows in this repository must pin immutable `comparevi-history` refs only.
- The automatic changed-VI PR wrappers currently pin the immutable platform commit
  `d0e92af4f36da76c946a194efe4c2cc79590629d` until the next released tag includes the new reusable workflows.
- Consumers in this repository must not pin `compare-vi-cli-action` directly.
- The normal released `comparevi-history` path already resolves its backend from the released
  `compare-vi-cli-action` bundle mapping.
- Consumer workflows here should not set maintainer-only backend override inputs such as `comparevi_repository` or
  `comparevi_ref`.
- The hosted invoke adapter resolves `Run-NILinuxContainerCompare.ps1` from `COMPAREVI_SCRIPTS_ROOT`, which is exported
  by the released platform while it runs the released backend bundle.
- Reviewer-facing consumers in this repository should rely on the action-owned outputs
  `public-comment-path`, `public-step-summary-path`, `public-run-path`, and `history-summary-json` instead of
  rebuilding markdown inline.

## Upstream and Fork Alignment

- The canonical upstream repo for this diagnostics shape is `LabVIEW-Community-CI-CD/labview-icon-editor-demo`.
- Downstream forks such as `svelderrainruiz/labview-icon-editor-demo` should keep these workflow files aligned to
  upstream unless they intentionally diverge on diagnostics policy.
- The workflows are repo-local by design: they query the pull request from the current repository, then check out the
  PR head repo and SHA exactly as reported by the GitHub API.
- The automatic changed-VI PR publisher does not check out the PR head again; it reads the execution artifact from the
  completed `pull_request` run through the `workflow_run` event and updates the sticky comment from those prepared
  files only.

## Target Catalog

- Current default target id: `vip-post-install-custom-action`
- Current target path: `Tooling/deployment/VIP_Post-Install Custom Action.vi`
- Public reviewer command: `/comparevi-history vip-post-install-custom-action --modes attributes,front-panel,block-diagram`
- Branch-budget policy is bounded in the checked-in target catalog, not assembled ad hoc in workflows.

## Recommended Usage

1. Start with the manual workflow when you want a low-risk maintainer-controlled diagnostics path.
2. Use the automatic changed-VI PR workflows as the standard reviewer surface when you want every touched `.vi` in a
   pull request to receive CompareVI History automatically.
3. Use target id `vip-post-install-custom-action` while validating the legacy catalog-based hosted-runner path.
4. Use the comment-gated workflow once maintainers are comfortable triggering diagnostics from PR comments on the
   hosted runner under maintainer-only command gating.
5. Keep the explicit public mode bundle `attributes,front-panel,block-diagram` unless there is a documented reason to
   narrow it further.
6. Use the manual VI exploration workflow when you want the full available revision catalog for a specific repo-relative
   `.vi` path rather than the curated target-id diagnostics contract.

## See Also

- [CI Workflows Overview](ci-workflows.md)
- [Documentation Index](README.md)
- [`comparevi-history` safe public template guidance](https://github.com/LabVIEW-Community-CI-CD/comparevi-history/blob/main/docs/SAFE_PR_DIAGNOSTICS_TEMPLATES.md)
