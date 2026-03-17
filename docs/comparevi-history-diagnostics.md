# CompareVI History Diagnostics

This repository consumes `comparevi-history` as the canonical released VI history platform surface for pull-request
review without running that platform directly from untrusted PR events.

## Workflows

- [`.github/workflows/comparevi-history-manual-vi-exploration.yml`](../.github/workflows/comparevi-history-manual-vi-exploration.yml)
  is a maintainer-dispatched workflow for exploring one repo-relative `.vi` path on demand through the published
  reusable `comparevi-history` manual exploration workflow. The wrapper stays thin: it forwards `vi_path`, `ref`,
  `compare_modes`, `include_merge_parents`, and `noise_policy`, and pins both the reusable workflow ref and
  `platform_ref` to `v1.3.0`.
- [`.github/workflows/comparevi-history-manual-pr-diagnostics.yml`](../.github/workflows/comparevi-history-manual-pr-diagnostics.yml)
  is a maintainer-dispatched workflow for inspecting a specific pull request and checked-in comparevi-history target id
  on demand.
- [`.github/workflows/comparevi-history-comment-gated.yml`](../.github/workflows/comparevi-history-comment-gated.yml)
  is a maintainer-only slash-command workflow that runs when a trusted maintainer comments
  `/comparevi-history <target-id> [--modes attributes,front-panel,block-diagram]` on a pull request.
- [`.github/comparevi-history-targets.json`](../.github/comparevi-history-targets.json) is the repo-owned target
  catalog that declares which VI history targets this consumer exposes.

The manual exploration workflow:

- pins the immutable reusable workflow
  `LabVIEW-Community-CI-CD/comparevi-history/.github/workflows/manual-vi-exploration.yml@v1.3.0`
- keeps `platform_ref` aligned with the workflow pin at `v1.3.0`
- accepts repo-relative `vi_path` input plus `ref`, `compare_modes`, `include_merge_parents`, and `noise_policy`
- uploads `revision-catalog.json`, `exploration-run.json`, `index.md`, `index.html`, `timeline.md`, `timeline.html`,
  and `manual-vi-exploration-bundle.zip`
- appends the reusable workflow summary to the workflow run
- does not add repo-local history discovery, chunk orchestration, or renderer logic

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

The manual exploration path is additive. Existing target-id PR diagnostics remain unchanged and continue to use the
checked-in target catalog.

## Release Contract

- Consumer workflows in this repository must pin released `comparevi-history` refs only.
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

## Target Catalog

- Current default target id: `vip-post-install-custom-action`
- Current target path: `Tooling/deployment/VIP_Post-Install Custom Action.vi`
- Public reviewer command: `/comparevi-history vip-post-install-custom-action --modes attributes,front-panel,block-diagram`
- Branch-budget policy is bounded in the checked-in target catalog, not assembled ad hoc in workflows.

## Recommended Usage

1. Start with the manual workflow when you want a low-risk maintainer-controlled diagnostics path.
2. Use target id `vip-post-install-custom-action` while validating hosted-runner and trust behavior.
3. Use the comment-gated workflow once maintainers are comfortable triggering diagnostics from PR comments on the
   hosted runner under maintainer-only command gating.
4. Keep the explicit public mode bundle `attributes,front-panel,block-diagram` unless there is a documented reason to
   narrow it further.
5. Use the manual VI exploration workflow when you want the full available revision catalog for a specific repo-relative
   `.vi` path rather than the curated target-id diagnostics contract.

## See Also

- [CI Workflows Overview](ci-workflows.md)
- [Documentation Index](README.md)
- [`comparevi-history` safe public template guidance](https://github.com/LabVIEW-Community-CI-CD/comparevi-history/blob/main/docs/SAFE_PR_DIAGNOSTICS_TEMPLATES.md)
