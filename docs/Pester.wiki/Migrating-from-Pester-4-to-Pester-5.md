:warning: Pester 5 currently in alpha mode.  This wiki page is likely out of date.  See [Readme.md](https://github.com/pester/Pester/tree/v5.0#pester-v5---alpha2) in v5.0 branch for latest updates.

## New Features in Pester v5

* Focused Tests and Test blocks using -Focus parameter.
* Implicit parameters for TestCases
* Improved debugging
* Test discovery

## Bug Fixes
* Internal functions are hidden
* Execution order

## Breaking Changes

1. Running tests interactively is not currently supported and will result in following console error:

```
Running tests interactively (e.g. by pressing F5 in your IDE) is not supported, run tests via Invoke-Pester.
```

## WIP
* Nested blocks and their setups
* Leaking scopes
