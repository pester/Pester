function Get-TestDrivePlugin {

    Pester.Runtime\New-PluginObject -Name "TestDrive" -EachBlockSetup {
        param($Context)
        if (-not ($Context.Block.PluginData.ContainsKey('TestDrive'))) {
            $Context.Block.PluginData.Add('TestDrive', @{
                    TestDriveAdded   = $false
                    TestDriveContent = $null
                })
        }

        # TODO: Add option, but probably in a more generic way
        # if (-not $NoTestDrive)
        # {
        if (-not (Test-Path TestDrive:\)) {
            New-TestDrive
            $Context.Block.PluginData.TestDrive.TestDriveAdded = $true
        }
        else {
            $Context.Block.PluginData.TestDrive.TestDriveContent = Get-TestDriveChildItem
        }
        # }

    } -EachBlockTearDown {
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
}

function New-TestDrive ([Switch]$PassThru, [string] $Path) {
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


function Clear-TestDrive ([String[]]$Exclude) {
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

function New-RandomTempDirectory {
    do {
        $tempPath = Get-TempDirectory
        $Path = & $SafeCommands['Join-Path'] -Path $tempPath -ChildPath ([Guid]::NewGuid())
    } until (-not (& $SafeCommands['Test-Path'] -Path $Path ))

    & $SafeCommands['New-Item'] -ItemType Container -Path $Path
}

function Get-TestDriveChildItem {
    $Path = (& $SafeCommands['Get-PSDrive'] -Name TestDrive).Root
    if (& $SafeCommands['Test-Path'] -Path $Path ) {
        & $SafeCommands['Get-ChildItem'] -Recurse -Path $Path
    }
}

function Remove-TestDriveSymbolicLinks ([String] $Path) {

    # remove symbolic links to work around problem with Remove-Item.
    # see https://github.com/PowerShell/PowerShell/issues/621
    #     https://github.com/pester/Pester/issues/1100

    # powershell 5 and higher
    # & $SafeCommands["Get-ChildItem"] -Recurse -Path $Path -Attributes "ReparsePoint" |
    #    % { $_.Delete() }

    # powershell 2-compatible
    $reparsePoint = [System.IO.FileAttributes]::ReparsePoint
    & $SafeCommands["Get-ChildItem"] -Recurse -Path $Path |
        where-object { ($_.Attributes -band $reparsePoint) -eq $reparsePoint } |
        % { $_.Delete() }

}

function Remove-TestDrive {

    $DriveName = "TestDrive"
    $Drive = & $SafeCommands['Get-PSDrive'] -Name $DriveName -ErrorAction $script:IgnoreErrorPreference
    $Path = ($Drive).Root


    if ($pwd -like "$DriveName*" ) {
        #will staying in the test drive cause issues?
        #TODO: review this
        & $SafeCommands['Write-Warning'] -Message "Your current path is set to ${pwd}:. You should leave ${DriveName}:\ before leaving Describe."
    }

    if ( $Drive ) {
        $Drive | & $SafeCommands['Remove-PSDrive'] -Force #This should fail explicitly as it impacts future pester runs
    }



    if ($null -ne $Path -and (& $SafeCommands['Test-Path'] -Path $Path)) {
        Remove-TestDriveSymbolicLinks -Path $Path
        & $SafeCommands['Remove-Item'] -Path $Path -Force -Recurse
    }

    if (& $SafeCommands['Get-Variable'] -Name $DriveName -Scope Global -ErrorAction $script:IgnoreErrorPreference) {
        & $SafeCommands['Remove-Variable'] -Scope Global -Name $DriveName -Force
    }
}
