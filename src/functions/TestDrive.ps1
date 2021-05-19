function Get-TestDrivePlugin {

    # TODO: add OnStart block and put this in it

    if (& $script:SafeCommands['Test-Path'] TestDrive:\) {
        & $SafeCommands['Remove-Item'] (& $SafeCommands['Get-PSDrive'] TestDrive -ErrorAction Stop).Root -Force -Recurse -Confirm:$false
        & $SafeCommands['Remove-PSDrive'] TestDrive
    }
    New-PluginObject -Name "TestDrive" -EachBlockSetupStart {
        param($Context)
        if (-not $profiler_testdrive) {
            if (-not ($Context.Block.PluginData.ContainsKey('TestDrive'))) {
                $Context.Block.PluginData.Add('TestDrive', @{
                        TestDriveAdded   = $false
                        TestDriveContent = $null
                    })
            }

            # TODO: Add option, but probably in a more generic way
            # if (-not $NoTestDrive)
            # {
            if (-not (& $script:SafeCommands['Test-Path'] TestDrive:\)) {
                New-TestDrive
                $Context.Block.PluginData.TestDrive.TestDriveAdded = $true
            }
            else {
                $Context.Block.PluginData.TestDrive.TestDriveContent = Get-TestDriveChildItem
            }
            # }
        }
        else {
            if ($Context.Block.IsRoot) {
                return
            }

            if ($Context.Block.Parent.IsRoot) {
                # this is top-level block setup test drive
                $path = New-TestDrive
                $Context.Block.PluginData.Add('TestDrive', @{
                        TestDriveAdded   = $true
                        TestDriveContent = $null
                        TestDrivePath    = $path
                    })
            }
            else {
                $testDrivePath = $Context.Block.Parent.PluginData.TestDrive.TestDrivePath
                $Context.Block.PluginData.Add('TestDrive', @{
                        TestDriveAdded   = $false
                        TestDriveContent = Get-TestDriveChildItem -TestDrivePath $testDrivePath
                        TestDrivePath    = $testDrivePath
                    })
            }
        }

    } -EachBlockTearDownEnd {
        param($Context)

        if (-not $profiler_testdrive) {
            # if (-not $NoTestDrive)
            # {
            if ($Context.Block.PluginData.TestDrive.TestDriveAdded) {
                Remove-TestDrive
            }
            else {
                Clear-TestDrive -Exclude ( $Context.Block.PluginData.TestDrive.TestDriveContent | & $SafeCommands['Select-Object'] -ExpandProperty FullName)
            }
            # }
        }
        else {
            if ($Context.Block.IsRoot) {
                return
            }

            if ($Context.Block.Parent -and $Context.Block.Parent.IsRoot) {
                # this is top-level block remove test drive
                Remove-TestDrive -TestDrivePath $Context.Block.PluginData.TestDrive.TestDrivePath
            }
            else {
                Clear-TestDrive -TestDrivePath $Context.Block.PluginData.TestDrive.TestDrivePath -Exclude ( $Context.Block.PluginData.TestDrive.TestDriveContent )
            }
        }
    }
}

function New-TestDrive ([Switch]$PassThru, [string] $Path) {
    if (-not $profiler_testdrive) {
        if ($Path -notmatch '\S') {
            $directory = New-RandomTempDirectory
        }
        else {
            if (-not (& $SafeCommands['Test-Path'] -Path $Path)) {
                $null = & $SafeCommands['New-Item'] -ItemType Container -Path $Path
            }

            $directory = & $SafeCommands['Get-Item'] $Path
        }

        $DriveName = "TestDrive"

        #setup the test drive
        if ( -not (& $SafeCommands['Test-Path'] "${DriveName}:\") ) {
            $null = & $SafeCommands['New-PSDrive'] -Name $DriveName -PSProvider FileSystem -Root $directory -Scope Global -Description "Pester test drive"
        }

        #publish the global TestDrive variable used in few places within the module
        if (-not (& $SafeCommands['Test-Path'] "Variable:Global:$DriveName")) {
            & $SafeCommands['New-Variable'] -Name $DriveName -Scope Global -Value $directory
        }

        if ( $PassThru ) {
            & $SafeCommands['Get-PSDrive'] -Name $DriveName
        }
    }
    else {
        $directory = New-RandomTempDirectory
        $DriveName = "TestDrive"
        $null = & $SafeCommands['New-PSDrive'] -Name $DriveName -PSProvider FileSystem -Root $directory -Scope Global -Description "Pester test drive"

        #publish the global TestDrive variable used in few places within the module
        if (-not (& $SafeCommands['Test-Path'] "Variable:Global:$DriveName")) {
            & $SafeCommands['New-Variable'] -Name $DriveName -Scope Global -Value $directory
        }

        $directory
    }
}


function Clear-TestDrive ([String[]]$Exclude, [string]$TestDrivePath) {
    if (-not $profiler_testdrive) {
        $drive = & $SafeCommands['Get-PSDrive'] -Name TestDrive -ErrorAction Ignore

        if ($null -eq $drive) {
            # someone cleared it up before us, maybe a Pester running in a child scope
            return
        }

        $Path = $drive.Root

        $Path = (& $SafeCommands['Get-PSDrive'] -Name TestDrive).Root
        if (& $SafeCommands['Test-Path'] -Path $Path ) {

            Remove-TestDriveSymbolicLinks -Path $Path

            #Get-ChildItem -Exclude did not seem to work with full paths
            & $SafeCommands['Get-ChildItem'] -Recurse -Path $Path |
                & $SafeCommands['Sort-Object'] -Descending  -Property "FullName" |
                & $SafeCommands['Where-Object'] { $Exclude -NotContains $_.FullName } |
                & $SafeCommands['Remove-Item'] -Force -Recurse

        }
    }
    else {
        if ([IO.Directory]::Exists($TestDrivePath)) {

            Remove-TestDriveSymbolicLinks -Path $TestDrivePath

            foreach ($i in [IO.Directory]::GetFileSystemEntries($TestDrivePath, "*.*", [System.IO.SearchOption]::AllDirectories)) {
                if ($Exclude -contains $i) {
                    continue
                }

                & $SafeCommands['Remove-Item'] -Force -Recurse $i -ErrorAction Ignore
            }
        }
    }
}

function New-RandomTempDirectory {
    if (-not $profiler_testdrive) {
        do {
            $tempPath = Get-TempDirectory
            $Path = & $SafeCommands['Join-Path'] -Path $tempPath -ChildPath ([Guid]::NewGuid())
        } until (-not (& $SafeCommands['Test-Path'] -Path $Path ))

        & $SafeCommands['New-Item'] -ItemType Container -Path $Path
    }
    else {
        do {
            $tempPath = Get-TempDirectory
            $Path = [IO.Path]::Combine($tempPath, ([Guid]::NewGuid()));
        } until (-not [IO.Directory]::Exists($Path))

        [IO.Directory]::CreateDirectory($Path)
    }
}

function Get-TestDriveChildItem ($TestDrivePath) {
    if (-not $profiler_testdrive) {
        $Path = (& $SafeCommands['Get-PSDrive'] -Name TestDrive).Root
        if (& $SafeCommands['Test-Path'] -Path $Path ) {
            & $SafeCommands['Get-ChildItem'] -Recurse -Path $Path
        }
    }
    else {
        if ([IO.Directory]::Exists($TestDrivePath)) {
            [IO.Directory]::GetFileSystemEntries($TestDrivePath, "*.*", [System.IO.SearchOption]::AllDirectories)
        }
    }
}

function Remove-TestDriveSymbolicLinks ([String] $Path) {

    # remove symbolic links to work around problem with Remove-Item.
    # see https://github.com/PowerShell/PowerShell/issues/621
    #     https://github.com/pester/Pester/issues/1100

    # powershell 5 and higher
    # & $SafeCommands["Get-ChildItem"] -Recurse -Path $Path -Attributes "ReparsePoint" |
    #    % { $_.Delete() }

    # issue 621 was fixed before PowerShell 6.1
    # now there is an issue with calling the Delete method in recent (6.1) builds of PowerShell
    if ( (GetPesterPSVersion) -ge 6) {
        return
    }

    # powershell 2-compatible
    $reparsePoint = [System.IO.FileAttributes]::ReparsePoint
    & $SafeCommands["Get-ChildItem"] -Recurse -Path $Path |
        & $SafeCommands['Where-Object'] { ($_.Attributes -band $reparsePoint) -eq $reparsePoint } |
        & $SafeCommands['Foreach-Object'] { $_.Delete() }
}

function Remove-TestDrive ($TestDrivePath) {
    $DriveName = "TestDrive"
    $Drive = & $SafeCommands['Get-PSDrive'] -Name $DriveName -ErrorAction Ignore
    $Path = ($Drive).Root

    if ($pwd -like "$DriveName*" ) {
        #will staying in the test drive cause issues?
        #TODO: review this
        & $SafeCommands['Write-Warning'] -Message "Your current path is set to ${pwd}:. You should leave ${DriveName}:\ before leaving Describe."
    }

    if ($Drive) {
        $Drive | & $SafeCommands['Remove-PSDrive'] -Force #This should fail explicitly as it impacts future pester runs
    }



    if ($null -ne $Path -and (& $SafeCommands['Test-Path'] -Path $Path)) {
        Remove-TestDriveSymbolicLinks -Path $Path
        & $SafeCommands['Remove-Item'] -Path $Path -Force -Recurse
    }

    if (& $SafeCommands['Get-Variable'] -Name $DriveName -Scope Global -ErrorAction Ignore) {
        & $SafeCommands['Remove-Variable'] -Scope Global -Name $DriveName -Force
    }
}
