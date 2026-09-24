<!--
  Release notes for the version in development.

  Written in one pass, before a release goes out. Not from every PR.

  Editing this file in every PR means every PR appends to the same list under the same
  anchor, so they conflict with each other even when the entries have nothing to do with
  one another. Each conflict costs a merge commit and a full CI run, and the same text
  gets reviewed again in every PR that happened to touch the file.

  One pass also keeps the original goal, which is that there is one set of notes to read
  and approve. The pass before the next prerelease only adds what merged since the last
  one, so it stays a small diff to review.

  Write the pass from the PRs merged since the last release. Their descriptions carry the
  reasoning, so this is not reconstructing anything from raw commit messages.

  The file is copied into the GitHub release body as it is, HTML comments do not render.
  When the stable release ships it is copied one last time, then emptied for the next line.

  Anchors are prefixed with the release line (6.2.1-...) so they stay valid across the
  prereleases and do not collide with other releases on the /releases page.
-->

# Pester 6.2.1

> 🙋 Want to share feedback or report a bug? Open an [issue](https://github.com/pester/Pester/issues/new/choose)
> or start a [discussion](https://github.com/pester/Pester/discussions).

A patch release with one fix. The experimental parallel runner printed the warnings from your
test files two or three times.

## <a id="6.2.1-fixes"></a>Fixes

- A warning written from a test file shows up once in a parallel run. `Run.Parallel` runs each
  file in a runspace pool that shares your console, so a `Write-Warning` from a test already
  reached the console while the file ran. Pester then wrote the worker's warning stream out a
  second time after the file finished, and a third time for the files that started first:

  ```powershell
  $c = New-PesterConfiguration
  $c.Run.Path = 'tests'
  $c.Run.Parallel = $true
  Invoke-Pester -Configuration $c

  # 6.2.0:
  # WARNING: cleaning up the cache failed
  # WARNING: cleaning up the cache failed
  # WARNING: cleaning up the cache failed
  ```

  Errors are not affected. A worker's errors never reach the console on their own, so those are
  still written out once when the file finishes. Reported in
  [pester/Pester#3044](https://github.com/pester/Pester/issues/3044) - *Warning stream is visible
  when running tests in parallel on Pester 6.2.0*, a regression from 6.2.0.

**Full Changelog**: https://github.com/pester/Pester/compare/6.2.0...6.2.1

## <a id="6.2.1-thank-you"></a>Thank you

Thank you to @kborowinski for reporting the duplicate warnings with a repro.

## <a id="6.2.1-questions"></a>Questions?

Open an [issue](https://github.com/pester/Pester/issues/new/choose) or start a
[discussion](https://github.com/pester/Pester/discussions).
