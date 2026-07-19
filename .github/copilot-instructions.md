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
- **Make changes through a pull request, and never force-push a branch.** Add new
  commits on top instead. We squash-merge, so the commit history inside a PR is
  irrelevant (it becomes a single commit on merge), and plain pushes avoid needless
  merge conflicts.

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

## Performance and the build analyzer

Pester ships custom PSScriptAnalyzer rules in `Pester.BuildAnalyzerRules/`. These rules
are **not** run by `build.ps1` or `test.ps1`; they only run in the `Code analysis`
workflow (`.github/workflows/code-analysis.yml`) on push and pull requests to `main`.
A green `test.ps1` run therefore does **not** mean the analyzer is happy — check it
locally before pushing:

```powershell
Install-Module PSScriptAnalyzer -Scope CurrentUser   # once
Invoke-ScriptAnalyzer -Path ./src -Recurse -Settings ./.github/workflows/PSScriptAnalyzerSettings.psd1
```

Two custom rules come up most often:

- **`Measure-ObjectCmdlets` — avoid the slow `*-Object` cmdlets in `src/`.** Do not use
  `Foreach-Object`, `Where-Object`, `Select-Object` or `New-Object`; they are slow
  compared to the language and .NET alternatives. Wrapping them as
  `& $SafeCommands['Foreach-Object']` does **not** satisfy the rule — it still fires.
  Use instead:
  - `foreach ($x in $items) { ... }` or a `for` loop instead of `... | Foreach-Object`.
  - the `.Where({ ... })` / `.ForEach({ ... })` array methods, or a `foreach` with `if`,
    instead of `... | Where-Object`.
  - direct member access (`$items.Name`) instead of `... | Select-Object -ExpandProperty`.
  - `[Type]::new(...)` instead of `New-Object Type`.
- **`Measure-SafeCommands` — call external commands through `$SafeCommands`.** Inside the
  module call `& $SafeCommands['Command-Name'] ...` instead of the bare command, so a
  user-defined function or alias cannot shadow it.

When a violation is truly unavoidable, suppress it explicitly next to the code with
`[Diagnostics.CodeAnalysis.SuppressMessageAttribute('Pester.BuildAnalyzerRules\<RuleName>', '<id>', Justification = '...')]`,
matching the existing suppressions in `src/`.

## Documentation

- Documentation is written in Markdown; update it when behavior changes.
- Use fenced code blocks for multi-line examples in comment-based help.
