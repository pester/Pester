Add-Type -TypeDefinition "
using System.Management.Automation;

public static class MemberFactory {
    public static PSNoteProperty CreateNoteProperty(string name, object value) {
        return new PSNoteProperty(name, value);
    }
}
"

function Find-RSpecTestFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String[]] $Path,
        [String[]] $ExcludePath
    )


    $files =
        foreach ($p in $Path) {
            if ([String]::IsNullOrWhiteSpace($p))
            {
                continue
            }

            if ((Test-Path $p)) {
                $item = Get-Item $p

                if ($item.PSIsContainer) {
                    # this is an existing directory search it for tests file
                    Get-ChildItem -Recurse -Path $p -Filter *.Tests.ps1 -File
                    continue
                }

                if ("FileSystem" -ne $item.PSProvider.Name) {
                    # item is not a directory and exists but is not a file so we are not interested
                    continue
                }

                if (".ps1" -ne $item.Extension) {
                    Write-Error "Script path '$p' is not a ps1 file." -ErrorAction Stop
                }

                # this is some file, we don't care if it is just a .ps1 file or .Tests.ps1 file
                Add-Member -Name UnresolvedPath -Type NoteProperty -Value $p -InputObject $item
                $item
                continue
            }

            # this is a path that does not exist so let's hope it is
            # a wildcarded path that will resolve to some files
            Get-ChildItem -Recurse -Path $p -Filter *.Tests.ps1 -File
        }

    Filter-Excluded -Files $files -ExludePath $ExcludePath
}

function Filter-Excluded ($Files, $ExludePath) {

    if ($null -eq $ExcludePath -or @($ExcludePath).Length -eq 0) {
        return @($Files)
    }

    foreach ($file in @($Files)) {
        # normalize backslashes for cross-platform ease of use
        $p = $file.FullName -replace "/","\"
        $excluded = $false

        foreach ($exclusion in (@($ExcludePath) -replace "/","\")) {
            if ($excluded) {
                continue
            }

            if ($p -like $exclusion) {
                $excluded = $true
            }
        }

        if (-not $excluded) {
            $file
        }
    }
}

function Add-RSpecTestObjectProperties {
    param ($TestObject)

    # adds properties that are specific to RSpec to the result object
    # this includes figuring out the result
    # formatting the failure message and stacktrace

    $result = if ($TestObject.Passed) {
        "Passed"
    }
    elseif ($TestObject.ShouldRun -and (-not $TestObject.Executed -or -not $TestObject.Passed)) {
        "Failed"
    }
    else {
        "Skipped"
    }

    $TestObject.PSObject.Properties.Add([MemberFactory]::CreateNoteProperty("Result", $result))

    # TODO: rename this to Duration, and rename duration to UserCodeDuration or something like that
    $time = [timespan]::zero + $TestObject.Duration + $TestObject.FrameworkDuration
    $TestObject.PSObject.Properties.Add([MemberFactory]::CreateNoteProperty("Time", $time))

    foreach ($e in $TestObject.ErrorRecord) {
        $r = ConvertTo-FailureLines $e
        $e.PSObject.Properties.Add([MemberFactory]::CreateNoteProperty("DisplayErrorMessage", [string]($r.Message -join [Environment]::NewLine)))
        $e.PSObject.Properties.Add([MemberFactory]::CreateNoteProperty("DisplayStackTrace", [string]($r.Trace -join [Environment]::NewLine)))
    }
}


function Get-RSpecObjectDecoratorPlugin () {
    Pester.Runtime\New-PluginObject -Name "RSpecObjectDecoratorPlugin" `
        -EachTestTeardownEnd {
        param ($Context)

        Add-RSpecTestObjectProperties $Context.Test
    }
}
