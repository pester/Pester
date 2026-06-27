# Copilot instructions for Pester

These instructions apply to all Copilot sessions working in this repository.

## GitHub workflow

- **Milestones:** When an issue is linked to a milestone, add the pull request that
  fixes it to the **same milestone**.
- **When you are nohwnd (the maintainer), don't push to a fork.** Push branches
  directly to the `pester/Pester` repository and open the pull request from there.
  (Other contributors may work from a personal fork as usual.)
- **Target branch:** Open pull requests against `main`.
- **Link the fixed issue in the PR, not in commits.** If a PR resolves an issue,
  reference it with `Fix #<issue_number>` in the **PR description** so the issue
  closes automatically on merge. Do **not** mention the fixed issue in commit
  messages (no `Fix #34:` prefix or similar) — it's unnecessary noise.
- Give every PR a meaningful title and a summary describing the changes.

## Building

Pester is written in PowerShell and C#. Build from the repository root:

```powershell
# First clone, or whenever the C# code changes (rebuilds assemblies):
.\build.ps1 -Clean

# When only PowerShell code changes:
.\build.ps1
```

> If the assemblies changed and a previous version is already loaded in the session,
> start a new PowerShell session before re-importing the module.

## Testing

Use `test.ps1`, which runs a build and imports required helpers before starting:

```powershell
.\test.ps1 -File <filename>              # run a specific test file
.\test.ps1 -File <filename> -SkipPTests  # skip the P-module (*.ts.ps1) tests
```

There are two kinds of tests:

- `*.ts.ps1` — P tests (unit tests for the runtime and acceptance tests for Pester).
- `*.tests.ps1` — Pester tests for the module's functions.

## Documentation

- Documentation is written in Markdown; update it when behavior changes.
- Use fenced code blocks for multi-line examples in comment-based help.
