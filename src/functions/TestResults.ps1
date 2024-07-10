function GetFullPath ([string]$Path) {
    $Folder = & $SafeCommands['Split-Path'] -Path $Path -Parent
    $File = & $SafeCommands['Split-Path'] -Path $Path -Leaf

    if ( -not ([String]::IsNullOrEmpty($Folder))) {
        if (-not (& $SafeCommands['Test-Path'] $Folder)) {
            $null = & $SafeCommands['New-Item'] $Folder -ItemType Container -Force
        }

        $FolderResolved = & $SafeCommands['Resolve-Path'] -Path $Folder
    }
    else {
        $FolderResolved = & $SafeCommands['Resolve-Path'] -Path $ExecutionContext.SessionState.Path.CurrentFileSystemLocation
    }

    $Path = & $SafeCommands['Join-Path'] -Path $FolderResolved.ProviderPath -ChildPath $File

    return $Path
}

function Export-PesterResult {
    param (
        [Pester.Run] $Result,
        [string] $Path,
        [string] $Format
    )

    switch -Wildcard ($Format) {
        'NUnit2.5' {
            Export-XmlReport -Result $Result -Path $Path -Format $Format
        }

        'NUnit3' {
            Export-XmlReport -Result $Result -Path $Path -Format $Format
        }

        '*Xml' {
            Export-XmlReport -Result $Result -Path $Path -Format $Format
        }

        default {
            throw "'$Format' is not a valid Pester export format."
        }
    }
}

function Export-NUnitReport {
    <#
    .SYNOPSIS
    Exports a Pester result-object to an NUnit-compatible XML-report

    .DESCRIPTION
    Pester can generate a result-object containing information about all
    tests that are processed in a run. This object can then be exported to an
    NUnit-compatible XML-report using this function. The report is generated
    using the NUnit 2.5-schema (default) or NUnit3-compatible format.

    This can be useful for further processing or publishing of test results,
    e.g. as part of a CI/CD pipeline.

    .PARAMETER Result
    Result object from a Pester-run. This can be retrieved using Invoke-Pester
    -Passthru or by using the Run.PassThru configuration-option.

    .PARAMETER Path
    The path where the XML-report should be saved.

    .PARAMETER Format
    Specifies the NUnit-schema to be used.

    .EXAMPLE
    ```powershell
    $p = Invoke-Pester -Passthru
    $p | Export-NUnitReport -Path TestResults.xml
    ```

    This example runs Pester using the Passthru option to retrieve the result-object and
    exports it as an NUnit 2.5-compatible XML-report.

    .LINK
    https://pester.dev/docs/commands/Export-NUnitReport

    .LINK
    https://pester.dev/docs/commands/Invoke-Pester
    #>
    param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Pester.Run] $Result,

        [parameter(Mandatory = $true)]
        [String] $Path,

        [ValidateSet('NUnit2.5', 'NUnit3')]
        [string] $Format = 'NUnit2.5'
    )

    Export-XmlReport -Result $Result -Path $Path -Format $Format
}

function Export-JUnitReport {
    <#
    .SYNOPSIS
    Exports a Pester result-object to an JUnit-compatible XML-report

    .DESCRIPTION
    Pester can generate a result-object containing information about all
    tests that are processed in a run. This object can then be exported to an
    JUnit-compatible XML-report using this function. The report is generated
    using the JUnit 4-schema.

    This can be useful for further processing or publishing of test results,
    e.g. as part of a CI/CD pipeline.

    .PARAMETER Result
    Result object from a Pester-run. This can be retrieved using Invoke-Pester
    -Passthru or by using the Run.PassThru configuration-option.

    .PARAMETER Path
    The path where the XML-report should be saved.

    .EXAMPLE
    ```powershell
    $p = Invoke-Pester -Passthru
    $p | Export-JUnitReport -Path TestResults.xml
    ```

    This example runs Pester using the Passthru option to retrieve the result-object and
    exports it as an JUnit 4-compatible XML-report.

    .LINK
    https://pester.dev/docs/commands/Export-JUnitReport

    .LINK
    https://pester.dev/docs/commands/Invoke-Pester
    #>
    param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Pester.Run] $Result,

        [parameter(Mandatory = $true)]
        [String] $Path
    )

    Export-XmlReport -Result $Result -Path $Path -Format JUnitXml
}

function Export-XmlReport {
    param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Pester.Run] $Result,

        [parameter(Mandatory = $true)]
        [String] $Path,

        [parameter(Mandatory = $true)]
        [ValidateSet('NUnitXml', 'NUnit2.5', 'NUnit3', 'JUnitXml')]
        [string] $Format
    )

    if ('NUnit2.5' -eq $Format) {
        $Format = 'NUnitXml'
    }

    #the xmlwriter create method can resolve relatives paths by itself. but its current directory might
    #be different from what PowerShell sees as the current directory so I have to resolve the path beforehand
    #working around the limitations of Resolve-Path
    $Path = GetFullPath -Path $Path

    $settings = [Xml.XmlWriterSettings] @{
        Indent              = $true
        NewLineOnAttributes = $false
    }

    $xmlFile = $null
    $xmlWriter = $null
    try {
        $xmlFile = [IO.File]::Create($Path)
        $xmlWriter = [Xml.XmlWriter]::Create($xmlFile, $settings)

        switch ($Format) {
            'NUnitXml' {
                Write-NUnitReport -XmlWriter $xmlWriter -Result $Result
            }

            'NUnit3' {
                Write-NUnit3Report -XmlWriter $xmlWriter -Result $Result
            }

            'JUnitXml' {
                Write-JUnitReport -XmlWriter $xmlWriter -Result $Result
            }
        }

        $xmlWriter.Flush()
        $xmlFile.Flush()
    }
    finally {
        if ($null -ne $xmlWriter) {
            try {
                $xmlWriter.Close()
            }
            catch {
            }
        }
        if ($null -ne $xmlFile) {
            try {
                $xmlFile.Close()
            }
            catch {
            }
        }
    }
}

function ConvertTo-NUnitReport {
    <#
    .SYNOPSIS
    Converts a Pester result-object to an NUnit 2.5 or 3-compatible XML-report

    .DESCRIPTION
    Pester can generate a result-object containing information about all
    tests that are processed in a run. This objects can then be converted to an
    NUnit-compatible XML-report using this function. The report is generated
    using either the NUnit 2.5 or 3-schema.

    The function can convert to both XML-object or a string containing the XML.
    This can be useful for further processing or publishing of test results,
    e.g. as part of a CI/CD pipeline.

    .PARAMETER Result
    Result object from a Pester-run. This can be retrieved using Invoke-Pester
    -Passthru or by using the Run.PassThru configuration-option.

    .PARAMETER AsString
    Returns the XML-report as a string.

    .PARAMETER Format
    Specifies the NUnit-schema to be used.

    .EXAMPLE
    ```powershell
    $p = Invoke-Pester -Passthru
    $p | ConvertTo-NUnitReport
    ```

    This example runs Pester using the Passthru option to retrieve the result-object and
    converts it to an NUnit 2.5-compatible XML-report. The report is returned as an XML-object.

    .EXAMPLE
    ```powershell
    $p = Invoke-Pester -Passthru
    $p | ConvertTo-NUnitReport -Format NUnit3
    ```

    This example runs Pester using the Passthru option to retrieve the result-object and
    converts it to an NUnit 3-compatible XML-report. The report is returned as an XML-object.

    .EXAMPLE
    ```powershell
    $p = Invoke-Pester -Passthru
    $p | ConvertTo-NUnitReport -AsString
    ```

    This example runs Pester using the Passthru option to retrieve the result-object and
    converts it to an NUnit 2.5-compatible XML-report. The returned object is a string.

    .LINK
    https://pester.dev/docs/commands/ConvertTo-NUnitReport

    .LINK
    https://pester.dev/docs/commands/Invoke-Pester
    #>
    [OutputType([xml], [string])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Pester.Run] $Result,
        [Switch] $AsString,

        [ValidateSet('NUnit2.5', 'NUnit3')]
        [string] $Format = 'NUnit2.5'
    )

    $settings = [Xml.XmlWriterSettings] @{
        Indent              = $true
        NewLineOnAttributes = $false
    }

    $stringWriter = $null
    $xmlWriter = $null
    try {
        $stringWriter = [IO.StringWriter]::new()
        $xmlWriter = [Xml.XmlWriter]::Create($stringWriter, $settings)

        switch ($Format) {
            'NUnit2.5' {
                Write-NUnitReport -XmlWriter $xmlWriter -Result $Result
            }

            'NUnit3' {
                Write-NUnit3Report -XmlWriter $xmlWriter -Result $Result
            }
        }

        $xmlWriter.Flush()
        $stringWriter.Flush()
    }
    finally {
        $xmlWriter.Close()
        if (-not $AsString) {
            [xml] $stringWriter.ToString()
        }
        else {
            $stringWriter.ToString()
        }
    }
}

function ConvertTo-JUnitReport {
    <#
    .SYNOPSIS
    Converts a Pester result-object to an JUnit-compatible XML report

    .DESCRIPTION
    Pester can generate a result-object containing information about all
    tests that are processed in a run. This objects can then be converted to an
    NUnit-compatible XML-report using this function. The report is generated
    using the JUnit 4-schema.

    The function can convert to both XML-object or a string containing the XML.
    This can be useful for further processing or publishing of test results,
    e.g. as part of a CI/CD pipeline.

    .PARAMETER Result
    Result object from a Pester-run. This can be retrieved using Invoke-Pester
    -Passthru or by using the Run.PassThru configuration-option.

    .PARAMETER AsString
    Returns the XML-report as a string.

    .EXAMPLE
    ```powershell
    $p = Invoke-Pester -Passthru
    $p | ConvertTo-JUnitReport
    ```

    This example runs Pester using the Passthru option to retrieve the result-object and
    converts it to an JUnit 4-compatible XML-report. The report is returned as an XML-object.

    .EXAMPLE
    ```powershell
    $p = Invoke-Pester -Passthru
    $p | ConvertTo-JUnitReport -AsString
    ```

    This example runs Pester using the Passthru option to retrieve the result-object and
    converts it to an JUnit 4-compatible XML-report. The returned object is a string.

    .LINK
    https://pester.dev/docs/commands/ConvertTo-JUnitReport

    .LINK
    https://pester.dev/docs/commands/Invoke-Pester
    #>
    [OutputType([xml], [string])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Pester.Run] $Result,
        [Switch] $AsString
    )

    $settings = [Xml.XmlWriterSettings] @{
        Indent              = $true
        NewLineOnAttributes = $false
    }

    $stringWriter = $null
    $xmlWriter = $null
    try {
        $stringWriter = [IO.StringWriter]::new()
        $xmlWriter = [Xml.XmlWriter]::Create($stringWriter, $settings)

        Write-JUnitReport -XmlWriter $xmlWriter -Result $Result

        $xmlWriter.Flush()
        $stringWriter.Flush()
    }
    finally {
        $xmlWriter.Close()
        if (-not $AsString) {
            [xml] $stringWriter.ToString()
        }
        else {
            $stringWriter.ToString()
        }
    }
}

function Get-TestTime($tests) {
    [TimeSpan]$totalTime = 0;
    if ($tests) {
        foreach ($test in $tests) {
            $totalTime += $test.time
        }
    }

    Convert-TimeSpan -TimeSpan $totalTime
}

function Convert-TimeSpan {
    param (
        [Parameter(ValueFromPipeline = $true)]
        $TimeSpan
    )
    process {
        if ($TimeSpan) {
            [string][math]::round(([TimeSpan]$TimeSpan).totalseconds, 4)
        }
        else {
            '0'
        }
    }
}

function Get-UTCTimeString ([datetime]$DateTime) {
    $DateTime.ToUniversalTime().ToString('o')
}

function Get-ErrorForXmlReport ($TestResult) {
    $failureMessage = if (($TestResult.ShouldRun -and -not $TestResult.Executed)) {
        'This test should run but it did not. Most likely a setup in some parent block failed.'
    }
    else {
        $multipleErrors = 1 -lt $TestResult.ErrorRecord.Count

        if ($multipleErrors) {
            $c = 0
            $(foreach ($err in $TestResult.ErrorRecord) {
                    "[$(($c++))] $($err.DisplayErrorMessage)"
                }) -join [Environment]::NewLine
        }
        else {
            $TestResult.ErrorRecord.DisplayErrorMessage
        }
    }

    $st = & {
        $multipleErrors = 1 -lt $TestResult.ErrorRecord.Count

        if ($multipleErrors) {
            $c = 0
            $(foreach ($err in $TestResult.ErrorRecord) {
                    "[$(($c++))] $($err.DisplayStackTrace)"
                }) -join [Environment]::NewLine
        }
        else {
            [string] $TestResult.ErrorRecord.DisplayStackTrace
        }
    }

    @{
        FailureMessage = $failureMessage
        StackTrace     = $st
    }
}

function Get-RunTimeEnvironment {
    # based on what we found during startup, use the appropriate cmdlet
    $computerName = $env:ComputerName
    $userName = $env:Username
    if ($null -ne $SafeCommands['Get-CimInstance']) {
        $osSystemInformation = (& $SafeCommands['Get-CimInstance'] Win32_OperatingSystem)
    }
    elseif ($null -ne $SafeCommands['Get-WmiObject']) {
        $osSystemInformation = (& $SafeCommands['Get-WmiObject'] Win32_OperatingSystem)
    }
    elseif ($IsMacOS -or $IsLinux) {
        $osSystemInformation = @{
            Name    = 'Unknown'
            Version = '0.0.0.0'
        }
        try {
            if ($null -ne $SafeCommands['uname']) {
                $osSystemInformation.Version = & $SafeCommands['uname'] -r
                $osSystemInformation.Name = & $SafeCommands['uname'] -s
                $computerName = & $SafeCommands['uname'] -n
            }
            if ($null -ne $SafeCommands['id']) {
                $userName = & $SafeCommands['id'] -un
            }
        }
        catch {
            # well, we tried
        }
    }
    else {
        $osSystemInformation = @{
            Name    = 'Unknown'
            Version = '0.0.0.0'
        }
    }

    @{
        'nunit-version'     = '2.5.8.0'
        'junit-version'     = '4'
        'os-version'        = $osSystemInformation.Version
        'platform'          = $osSystemInformation.Name
        'cwd'               = $pwd.Path
        'machine-name'      = $computerName
        'user'              = $username
        'user-domain'       = $env:userDomain
        'clr-version'       = [string][System.Environment]::Version
        'framework-version' = [string]$ExecutionContext.SessionState.Module.Version
    }
}

function Get-TestResultPlugin {
    # Validate configuration
    Resolve-TestResultConfiguration

    $p = @{
        Name = 'TestResult'
    }

    $p.End = {
        param($Context)

        $run = $Context.TestRun
        $testResultConfig = $PesterPreference.TestResult
        Export-PesterResult -Result $run -Path $testResultConfig.OutputPath.Value -Format $testResultConfig.OutputFormat.Value
    }

    New-PluginObject @p
}

function Resolve-TestResultConfiguration {
    $supportedFormats = 'NUnitXml', 'NUnit2.5', 'NUnit3', 'JUnitXml'
    if ($PesterPreference.TestResult.OutputFormat.Value -notin $supportedFormats) {
        throw (Get-StringOptionErrorMessage -OptionPath 'TestResult.OutputFormat' -SupportedValues $supportedFormats -Value $PesterPreference.TestResult.OutputFormat.Value)
    }
}
