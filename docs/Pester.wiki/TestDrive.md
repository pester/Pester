TestDrive is a PowerShell PSDrive for file activity limited to the scope of a single Describe or Context block.

A test may need to work with file operations and validate certain types of file activities. It is usually desirable not to perform file activity tests that will produce side effects outside of an individual test. Pester creates a PSDrive inside the user's temporary drive that is accessible via a named PSDrive ```TestDrive:```. Pester will remove this drive after the test completes. You may use this drive to isolate the file operations of your test to a temporary store.

## Scoping

Basic scoping rules are implemented for the TestDrive. A clean TestDrive is created for every Describe and all the files created are available in the whole Describe scope. If the Context keyword is also used the state of the TestDrive is recorded before moving into the Context block. Inside the Context block the files from the Describe scope are available for reading and modification. You can move them around and create new ones as well.

Once the Context block is finished all the files created inside that block are deleted, leaving only the files created in the Describe block. When the Describe block is finished all contents of the TestDrive are discarded.

Recording the state of the drive is done by saving a list of the files and folders present on the drive. No snapshots or any other magic is done. In practice this means that if you create a file in the Describe block and then change its content inside the Context block, the modifications are preserved even after you left the Context block.

Internally the TestDrive creates a randomly named folder placed in $env:Temp and links it to the TestDrive PSDrive. Making the folder names random enables you to run multiple instances of Pester in parallel, as long as they are running as separate processes. That means running in different PowerShell.exe sessions or running using PowerShell jobs.

## Example

```powershell
function Add-Footer($path, $footer) {
    Add-Content $path -Value $footer
}

Describe "Add-Footer" {
    $testPath = "TestDrive:\test.txt"
    Set-Content $testPath -value "my test text."
    Add-Footer $testPath "-Footer"
    $result = Get-Content $testPath

    It "adds a footer" {
        (-join $result) | Should -Be "my test text.-Footer"
    }
}
```

## Compare with Literal Path

Use the $TestDrive variable to compare regular paths with TestDrive paths.  The following
two paths will refer to the same file on disk, but the first one will contain the full file
system path to the root of the TestDrive PSDrive, rather than a PowerShell path starting with
'TestDrive:\'.

```powershell
#eg. C:\Users\nohwnd\AppData\Local\Temp\264f1c74-464f-4387-b908-79e5eecba982\somefile.txt
$pathOne = Join-Path $TestDrive 'somefile.txt'

$pathTwo = 'TestDrive:\somefile.txt'
```

To get the full path, you can use this snippet:

```powershell
function GetFullPath {
    Param(
        [string] $Path
    )
    return $Path.Replace('TestDrive:', (Get-PSDrive TestDrive).Root)
}
```

## Working with .NET Objects

When working directly with .NET objects, it's not possible to use the convenient `TestDrive:\` PSDrive. Instead you need to use the `$TestDrive` variable which holds the actual path in a format that .NET understands. For example instead of using `TestDrive:\somefile.txt` use `$TestDrive\somefile.txt` instead.
