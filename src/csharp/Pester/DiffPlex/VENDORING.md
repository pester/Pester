# Vendored DiffPlex

This folder is a copy of part of [DiffPlex](https://github.com/mmanela/diffplex). Pester compiles it
into `Pester.dll` rather than shipping `DiffPlex.dll` next to it.

## What is vendored

| | |
|---|---|
| Version | **1.9.0** |
| Upstream commit | `8821ff9` ("package", 2025-09-13), the commit that published 1.9.0 |
| Upstream repository | https://github.com/mmanela/diffplex |
| Licence | Apache-2.0, the same licence as Pester. See `LICENSE.txt` in this folder. |
| Files | 19 `.cs` files, 1080 lines |
| Cost | about 19 KB of `Pester.dll` per target framework, with embedded symbols |

At the time of writing the DiffPlex `DiffPlex/` folder is byte-identical between commit `8821ff9`
and `master` (`f500e73`, 2025-11-19).

## Modifications

**One, applied to every file:** the namespace is `Pester.DiffPlex` instead of `DiffPlex`, so the
types do not collide with a real DiffPlex that a user's session may already have loaded. That is a
rewrite of the `namespace` and `using` lines and nothing else.

Every file is otherwise byte-identical to upstream, and `LICENSE.txt` is unmodified.
`Update-VendoredDiffPlex.ps1` in this folder verifies this, run it with `-Verify`.

Apache-2.0 requires stating significant modifications, which the paragraph above does. The upstream
source files carry no per-file copyright header, so there are no in-file notices to preserve.

## Why vendor instead of referencing the package

Shipping `DiffPlex.dll` next to `Pester.dll` puts a second assembly identity in the user's session.
Windows PowerShell 5.1 has no load-context isolation, so if another module has already loaded a
different DiffPlex version there is a conflict Pester cannot do anything about. Compiling the part
we use into `Pester.dll` removes that, for fewer bytes than the full library.

It also keeps the build simple. No `PackageReference`, no `CopyLocalLockFileAssemblies`, and no
build.ps1 copy steps for two target frameworks.

## What is not vendored

Roughly half the library, 991 lines: `ThreeWayDiffer.cs`, `Renderer/UnidiffRenderer.cs`,
`DiffBuilder/InlineDiffBuilder.cs` and the three-way model types. Pester renders its own output, see
`../StringDiff.cs`.

Three files are here only because `Differ.cs` refers to them from convenience methods Pester does
not call: `Chunkers/LineChunker.cs`, `Chunkers/CharacterChunker.cs` and
`Chunkers/CustomFunctionChunker.cs`, 57 lines together. `Chunkers/DelimiterChunker.cs` is here
because `WordChunker` inherits it. Removing any of them would mean editing `Differ.cs`, which turns
an unmodified copy into a modified one for very few bytes.

## How often upstream releases

19 versions between 2011 and 2025, and about one a year recently: 1.7.1 (2022-03), 1.7.2 (2023-12),
1.8.0 (2025-05), 1.9.0 (2025-09). There is no need to track it closely. Check when a bug in the
diffing itself points at it.

## Updating

```powershell
./Update-VendoredDiffPlex.ps1 -Commit <upstream commit or tag>
```

The script clones upstream, copies the same file list, applies the namespace rewrite, and updates
the version table above. Run the Pester test suite afterwards, `tst/functions/assert/String/` covers
the rendering and `src/csharp/PesterTests/StringDiffTests.cs` covers the engine.

To check the copy has not drifted without updating it:

```powershell
./Update-VendoredDiffPlex.ps1 -Verify
```
