# Pester 5.0.0

> 💵 I am spending most of my weekends making this happen. These release notes for example took multiple days to write and update. Consider sponsoring [me](https://github.com/sponsors/nohwnd) or sponsoring [Pester](https://opencollective.com/pester), please.

> 🙋‍ Want to share feedback? [Go here](https://github.com/pester/Pester/issues/1218), or see more options in [Questions?](#questions).





### Collecting `AfterEach` failures

In a similar fashion to Should, when test assertion fails, and it teardown also fails you will see both errors:

```
[-] fails the test 30ms (24ms|5ms)
 [0] Expected 2, but got 1.
 at 1 | Should -Be 2
 [1] RuntimeException: but also fails in after each
```

### Normal, Detailed and Diagnostic view

Errors are usually what we are interested in when running tests. And that is why Pester5 implements a concise view that prints failed tests with the full test path, and minimal discovery and summary information:

```
Starting test discovery in 1 files.
Test discovery finished. 83ms
[-] output.fails 24ms (18ms|5ms)
 Expected 2, but got 1.
 at 1 | Should -Be 2, C:\Projects\pester\Pester.RSpec.Demo.ts.ps1:289
 at <ScriptBlock>, C:\Projects\pester\Pester.RSpec.Demo.ts.ps1:289
[-] output.child.fails 22ms (16ms|5ms)
 Expected 2, but got 1.
 at 1 | Should -Be 2, C:\Projects\pester\Pester.RSpec.Demo.ts.ps1:298
 at <ScriptBlock>, C:\Projects\pester\Pester.RSpec.Demo.ts.ps1:298
Tests completed in 331ms
Tests Passed: 4, Failed: 2, Skipped: 0, Total: 6, NotRun: 0
```

Pester5 also implements a Diagnostic view that prints information from Discovery, Filter, Skip, Mock and other sources, this output will be by default enabled when debugging tests in VSCode, or you can enable it by using `-Output Diagnostic`.

```shell
Mock: Found 2 behaviors for 'Get-Emoji':
    Body: { '🚒' }
    Filter: { $Emoji -eq 'firetruck' }
    Verifiable: False
    Body: { '🔥' }
    Filter: $null
    Verifiable: False
Mock: We are in a test. Returning mock table from test scope.
Mock: Finding a mock behavior.
Mock: Running mock filter {  $Emoji -eq 'firetruck'  } with context: Emoji = firetruck.
Mock: Mock filter passed.
Mock: {  '🚒'  } passed parameter filter and will be used for the mock call.
Mock: Executing mock behavior for mock Get-Emoji.
Mock: Behavior for Get-Emoji was executed.
Mock: Removing function PesterMock_3b8fd8ae-de6a-4a1c-87a8-7b177071f4af and aliases Get-Emoji for Get-Emoji.
  [+] Gets firetruck 2.78s (2.71s|64ms)
Tests completed in 4.71s
Tests Passed: 1, Failed: 0, Skipped: 0 NotRun: 0
```

### New result object

The new result object is extremely rich, and used by Pester internally to make all of its decisions. Most of the information in the tree is unprocessed to allow you to to work with the raw data. You are welcome to inspect the object, and write your code based on it.

To use your current CI pipeline with the new object use `ConvertTo-Pester4Result` to convert it. To convert the new object to NUnit report use `ConvertTo-NUnitReport` or specify the `-CI` switch to enable NUnit output, code coverage and exit code on failure.


#### Simple interface

The simple interface is what I mostly need to run my tests. It uses some sensible defaults, and most of the parameters are hopefully self explanatory. The CI switch enables NUnit output to `testResults.xml`, code coverage that is automatically figured out from the provided files and exported into coverage.xml and also enables exit with error code when anything fails.






## Breaking changes

#


