#
function New-TestRegistry
{
    param(
        [Switch]
        $PassThru,

        [string]
        $Path
    )

    if ($Path -notmatch '\S')
    {
        $directory = New-RandomTempRegistry
    }
    else
    {
        if (-not (& $SafeCommands['Test-Path'] -Path $Path))
        {
            $null = & $SafeCommands['New-Item'] -Path $Path -Force
        }

        $directory = & $SafeCommands['Get-Item'] $Path
    }

    $DriveName = "TestRegistry"
    #setup the test drive
    if ( -not (& $SafeCommands['Test-Path'] "${DriveName}:\") )
    {
        try {
            $null = & $SafeCommands['New-PSDrive'] -Name $DriveName -PSProvider Registry -Root $directory -Scope Global -Description "Pester test registry" -ErrorAction Stop
        }
        catch {
            if ($_.FullyQualifiedErrorId -like 'DriveAlreadyExists*') {
                # it can happen that Test-Path reports false even though the drive
                # exists. I don't know why but I see it in "Context Teardown fails"
                # it would be possible to use Get-PsDrive directly for the test but it
                # is about 10ms slower and we do it in every Describe and It so it would
                # quickly add up

                # so if that happens just ignore the error, the goal of this function is to
                # create the testdrive and the testdrive already exists, so all is good.
            }
            else
            {
                Write-Error $_ -ErrorAction 'Stop'
            }
        }
    }
    else {
        write-host "registry drive exists"
    }

    if ( $PassThru )
    {
        & $SafeCommands['Get-PSDrive'] -Name $DriveName
    }
}

function Get-TestRegistryPath () {
    "Microsoft.PowerShell.Core\Registry::" + (& $SafeCommands['Get-PSDrive'] -Name TestRegistry).Root
}

function Clear-TestRegistry
{
    param(
        [String[]]
        $Exclude
    )

    $path = Get-TestRegistryPath

    if ($null -ne $path -and (& $SafeCommands['Test-Path'] -Path $Path))
    {
        #Get-ChildItem -Exclude did not seem to work with full paths
        & $SafeCommands['Get-ChildItem'] -Recurse -Path $Path |
            & $SafeCommands['Sort-Object'] -Descending  -Property 'PSPath' |
            & $SafeCommands['Where-Object'] { $Exclude -NotContains $_.PSPath } |
            & $SafeCommands['Remove-Item'] -Force -Recurse
    }
}

function Get-TestRegistryChildItem {
    $path = Get-TestRegistryPath

    & $SafeCommands['Get-ChildItem'] -Recurse -Path $path
}

function New-RandomTempRegistry
{
    do
    {
        $tempPath = Get-TempRegistry
        $Path = & $SafeCommands['Join-Path'] -Path $tempPath -ChildPath ([Guid]::NewGuid())
    } until (-not (& $SafeCommands['Test-Path'] -Path $Path ))

    & $SafeCommands['New-Item'] -Path $Path -Force
}

function Remove-TestRegistry
{
    $DriveName = "TestRegistry"
    $Drive = & $SafeCommands['Get-PSDrive'] -Name $DriveName -ErrorAction $script:IgnoreErrorPreference
    if ($null -eq $Drive) {
        # the drive does not exist, someone must have removed it instead of us,
        # most likely a test that tests pester itself, so we just hope that the
        # one who removed this removed also the contents of it correctly
        return
    }

    $path = Get-TestRegistryPath

    if ($pwd -like "$DriveName*" )
    {
        #will staying in the test drive cause issues?
        #TODO review this
        & $SafeCommands['Write-Warning'] -Message "Your current path is set to ${pwd}:. You should leave ${DriveName}:\ before leaving Describe."
    }

    if ( $Drive )
    {
        $Drive | & $SafeCommands['Remove-PSDrive'] -Force #This should fail explicitly as it impacts future pester runs
    }

    if (& $SafeCommands['Test-Path'] -Path $path)
    {
        & $SafeCommands['Remove-Item'] -Path $path -Force -Recurse
    }

    if (& $SafeCommands['Get-Variable'] -Name $DriveName -Scope Global -ErrorAction $script:IgnoreErrorPreference)
    {
        & $SafeCommands['Remove-Variable'] -Scope Global -Name $DriveName -Force
    }
}
