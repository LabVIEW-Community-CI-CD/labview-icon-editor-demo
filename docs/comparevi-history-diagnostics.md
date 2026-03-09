# CompareVI History Diagnostics

This repository can consume `comparevi-history` as a released diagnostics facade for pull-request review without
running that facade directly from untrusted PR events.

## Workflows

- [`.github/workflows/comparevi-history-manual-pr-diagnostics.yml`](../.github/workflows/comparevi-history-manual-pr-diagnostics.yml)
  is a maintainer-dispatched workflow for inspecting a specific pull request and repository-relative VI path on demand.
- [`.github/workflows/comparevi-history-comment-gated.yml`](../.github/workflows/comparevi-history-comment-gated.yml)
  is a maintainer-only slash-command workflow that runs when a trusted maintainer comments
  `/comparevi-history <repository-relative-vi-path> [--modes comma,list]` on a pull request.

Both workflows:

- use released `LabVIEW-Community-CI-CD/comparevi-history` refs only
- run on `ubuntu-latest`
- pre-pull `nationalinstruments/labview:2026q1-linux` under a repo-level concurrency group so image acquisition and
  compare execution stay serialized
- resolve the PR head repository and SHA dynamically
- use the repo-local `Tooling/Invoke-CompareVIHistoryHostedNILinux.ps1` adapter as a maintainer-controlled
  `invoke_script_path`
- upload diagnostics artifacts plus reviewer-facing mode summaries

## Release Contract

- Consumer workflows in this repository must pin released `comparevi-history` refs only.
- Consumers in this repository must not pin `compare-vi-cli-action` directly.
- The normal released `comparevi-history` path already resolves its backend from the released
  `compare-vi-cli-action` bundle mapping.
- Consumer workflows here should not set maintainer-only backend override inputs such as `comparevi_repository` or
  `comparevi_ref`.
- The hosted invoke adapter resolves `Run-NILinuxContainerCompare.ps1` from `COMPAREVI_SCRIPTS_ROOT`, which is exported
  by the released facade while it runs the released backend bundle.

## Upstream and Fork Alignment

- The canonical upstream repo for this diagnostics shape is `LabVIEW-Community-CI-CD/labview-icon-editor-demo`.
- Downstream forks such as `svelderrainruiz/labview-icon-editor-demo` should keep these workflow files aligned to
  upstream unless they intentionally diverge on diagnostics policy.
- The workflows are repo-local by design: they query the pull request from the current repository, then check out the
  PR head repo and SHA exactly as reported by the GitHub API.

## Recommended Usage

1. Start with the manual workflow when you want a low-risk maintainer-controlled diagnostics path.
2. Use a stable VI path such as `Tooling/deployment/VIP_Post-Install Custom Action.vi` while validating hosted-runner
   and trust behavior.
3. Add the comment-gated workflow once maintainers are comfortable triggering diagnostics from PR comments on the
   hosted runner under maintainer-only command gating.
4. Keep the default mode bundle `default,attributes,front-panel,block-diagram` unless there is a documented reason to
   narrow it.

## See Also

- [CI Workflows Overview](ci-workflows.md)
- [Documentation Index](README.md)
- [`comparevi-history` safe public template guidance](https://github.com/LabVIEW-Community-CI-CD/comparevi-history/blob/main/docs/SAFE_PR_DIAGNOSTICS_TEMPLATES.md)
