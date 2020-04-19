$Paths = @(
    "$PSScriptRoot/csharp/Configuration.cs"
    "$PSScriptRoot/csharp/Factory.cs"
    "$PSScriptRoot/csharp/Test.cs"
)

foreach ($path in $Paths) {
    Add-Type -TypeDefinition (Get-Content -Raw $path) -ErrorAction Stop
}

Add-Type -TypeDefinition @"
using System;
namespace Pester
{
    [Flags]
    public enum OutputTypes
    {
        None = 0,
        Default = 1,
        Passed = 2,
        Failed = 4,
        Pending = 8,
        Skipped = 16,
        Inconclusive = 32,
        Describe = 64,
        Context = 128,
        Summary = 256,
        Header = 512,
        All = Default | Passed | Failed | Pending | Skipped | Inconclusive | Describe | Context | Summary | Header,
        Fails = Default | Failed | Pending | Skipped | Inconclusive | Describe | Context | Summary | Header
    }
}
"@
