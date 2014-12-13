function Get-HumanTime($Seconds) {
    if($Seconds -gt 0.99) {
        $time = [math]::Round($Seconds, 2)
        $unit = 's'
    }
    else {
        $time = [math]::Floor($Seconds * 1000)
        $unit = 'ms'
    }
    return "$time$unit"
}

function GetFullPath ([string]$Path) {
    if (-not [System.IO.Path]::IsPathRooted($Path))
    {
        $Path = Join-Path $ExecutionContext.SessionState.Path.CurrentFileSystemLocation $Path
    }

    return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
}

function Export-PesterResults
{
    param (
        $PesterState,
        [string] $Path,
        [string] $Format
    )

    switch ($Format)
    {
        'LegacyNUnitXml' { Export-NUnitReport -PesterState $PesterState -Path $Path -LegacyFormat }
        'NUnitXml'       { Export-NUnitReport -PesterState $PesterState -Path $Path }

        default
        {
            throw "'$Format' is not a valid Pester export format."
        }
    }
}
function Export-NUnitReport {
    param (
        [parameter(Mandatory=$true,ValueFromPipeline=$true)]
        $PesterState,

        [parameter(Mandatory=$true)]
        [String]$Path,

        [switch] $LegacyFormat
    )

    #the xmlwriter create method can resolve relatives paths by itself. but its current directory might
    #be different from what PowerShell sees as the current directory so I have to resolve the path beforehand
    #working around the limitations of Resolve-Path

    $Path = GetFullPath -Path $Path

    $settings = New-Object -TypeName Xml.XmlWriterSettings -Property @{
        Indent = $true
        NewLineOnAttributes = $false
    }

    $xmlWriter = $null
    try {
        $xmlWriter = [Xml.XmlWriter]::Create($Path,$settings)

        Write-NUnitReport -XmlWriter $xmlWriter -PesterState $PesterState -LegacyFormat:$LegacyFormat

        $xmlWriter.Flush()
    }
    finally
    {
        if ($null -ne $xmlWriter) {
            try { $xmlWriter.Close() } catch {}
        }
    }
}

function Write-NUnitReport($PesterState, [System.Xml.XmlWriter] $XmlWriter, [switch] $LegacyFormat)
{
    # Write the XML Declaration
    $XmlWriter.WriteStartDocument($false)

    # Write Root Element
    $xmlWriter.WriteStartElement('test-results')

    Write-NUnitTestResultAttributes @PSBoundParameters
    Write-NUnitTestResultChildNodes @PSBoundParameters

    $XmlWriter.WriteEndElement()
}

function Write-NUnitTestResultAttributes($PesterState, [System.Xml.XmlWriter] $XmlWriter, [switch] $LegacyFormat)
{
    $XmlWriter.WriteAttributeString('xmlns','xsi', $null, 'http://www.w3.org/2001/XMLSchema-instance')
    $XmlWriter.WriteAttributeString('xsi','noNamespaceSchemaLocation', [Xml.Schema.XmlSchema]::InstanceNamespace , 'nunit_schema_2.5.xsd')
    $XmlWriter.WriteAttributeString('name','Pester')
    $XmlWriter.WriteAttributeString('total', $PesterState.TotalCount)
    $XmlWriter.WriteAttributeString('errors', '0')
    $XmlWriter.WriteAttributeString('failures', $PesterState.FailedCount)
    $XmlWriter.WriteAttributeString('not-run', '0')
    $XmlWriter.WriteAttributeString('inconclusive', $PesterState.PendingCount)
    $XmlWriter.WriteAttributeString('ignored', '0')
    $XmlWriter.WriteAttributeString('skipped', $PesterState.SkippedCount)
    $XmlWriter.WriteAttributeString('invalid', '0')
    $date = Get-Date
    $XmlWriter.WriteAttributeString('date', (Get-Date -Date $date -Format 'yyyy-MM-dd'))
    $XmlWriter.WriteAttributeString('time', (Get-Date -Date $date -Format 'HH:mm:ss'))
}

function Write-NUnitTestResultChildNodes($PesterState, [System.Xml.XmlWriter] $XmlWriter, [switch] $LegacyFormat)
{
    Write-NUnitEnvironmentInformation @PSBoundParameters
    Write-NUnitCultureInformation @PSBoundParameters

    $XmlWriter.WriteStartElement('test-suite')
    Write-NUnitGlobalTestSuiteAttributes @PSBoundParameters

    $XmlWriter.WriteStartElement('results')

    Write-NUnitDescribeElements @PSBoundParameters

    $XmlWriter.WriteEndElement()
    $XmlWriter.WriteEndElement()
}

function Write-NUnitEnvironmentInformation($PesterState, [System.Xml.XmlWriter] $XmlWriter, [switch] $LegacyFormat)
{
    $XmlWriter.WriteStartElement('environment')

    $environment = Get-RunTimeEnvironment
    foreach ($keyValuePair in $environment.GetEnumerator()) {
        $XmlWriter.WriteAttributeString($keyValuePair.Name, $keyValuePair.Value)
    }

    $XmlWriter.WriteEndElement()
}

function Write-NUnitCultureInformation($PesterState, [System.Xml.XmlWriter] $XmlWriter, [switch] $LegacyFormat)
{
    $XmlWriter.WriteStartElement('culture-info')

    $XmlWriter.WriteAttributeString('current-culture', ([System.Threading.Thread]::CurrentThread.CurrentCulture).Name)
    $XmlWriter.WriteAttributeString('current-uiculture', ([System.Threading.Thread]::CurrentThread.CurrentUiCulture).Name)

    $XmlWriter.WriteEndElement()
}

function Write-NUnitGlobalTestSuiteAttributes($PesterState, [System.Xml.XmlWriter] $XmlWriter, [switch] $LegacyFormat)
{
    $XmlWriter.WriteAttributeString('type', 'Powershell')
    $XmlWriter.WriteAttributeString('name', $PesterState.Path)
    $XmlWriter.WriteAttributeString('executed', 'True')

    $isSuccess = $PesterState.FailedCount -eq 0
    $result = Get-ParentResult $PesterState
    $XmlWriter.WriteAttributeString('result', $result)
    $XmlWriter.WriteAttributeString('success',[string]$isSuccess)
    $XmlWriter.WriteAttributeString('time',(Convert-TimeSpan $PesterState.Time))
    $XmlWriter.WriteAttributeString('asserts','0')
}

function Write-NUnitDescribeElements($PesterState, [System.Xml.XmlWriter] $XmlWriter, [switch] $LegacyFormat)
{
    $Describes = $PesterState.TestResult | Group-Object -Property Describe
    foreach ($currentDescribe in $Describes)
    {
        $DescribeInfo = Get-TestSuiteInfo $currentDescribe

        #Write test suites
        $XmlWriter.WriteStartElement('test-suite')

        if ($LegacyFormat) { $suiteType = 'PowerShell' } else { $suiteType = 'TestFixture' }

        Write-NUnitTestSuiteAttributes -TestSuiteInfo $DescribeInfo -TestSuiteType $suiteType -XmlWriter $XmlWriter -LegacyFormat:$LegacyFormat

        $XmlWriter.WriteStartElement('results')

        Write-NUnitDescribeChildElements -TestResults $currentDescribe.Group -XmlWriter $XmlWriter -LegacyFormat:$LegacyFormat -DescribeName $DescribeInfo.Name

        $XmlWriter.WriteEndElement()
        $XmlWriter.WriteEndElement()
    }
}

function Get-TestSuiteInfo ([Microsoft.PowerShell.Commands.GroupInfo]$TestSuiteGroup)
{
    $suite = @{
        resultMessage = 'Failure'
        success = 'False'
        totalTime = '0.0'
        name = $TestSuiteGroup.Name
        description = $TestSuiteGroup.Name
    }

    #calculate the time first, I am converting the time into string in the TestCases
    $suite.totalTime = (Get-TestTime $TestSuiteGroup.Group)
    $suite.success = (Get-TestSuccess $TestSuiteGroup.Group)
    $suite.resultMessage = Get-GroupResult $TestSuiteGroup.Group
    $suite
}

function Get-TestTime($tests) {
    [TimeSpan]$totalTime = 0;
    if ($tests)
    {
        foreach ($test in $tests)
        {
            $totalTime += $test.time
        }
    }

    Convert-TimeSpan -TimeSpan $totalTime
}
function Convert-TimeSpan {
    param (
        [Parameter(ValueFromPipeline=$true)]
        $TimeSpan
    )
    process {
        if ($TimeSpan) {
            [string][math]::round(([TimeSpan]$TimeSpan).totalseconds,4)
        }
        else
        {
            '0'
        }
    }
}
function Get-TestSuccess($tests) {
    $result = $true
    if ($tests)
    {
        foreach ($test in $tests) {
            if (-not $test.Passed) {
                $result = $false
                break
            }
        }
    }
    [String]$result
}
function Write-NUnitTestSuiteAttributes($TestSuiteInfo, [System.Xml.XmlWriter] $XmlWriter, [string] $TestSuiteType, [switch] $LegacyFormat)
{
    $XmlWriter.WriteAttributeString('type', $TestSuiteType)
    $XmlWriter.WriteAttributeString('name', $TestSuiteInfo.name)
    $XmlWriter.WriteAttributeString('executed', 'True')
    $XmlWriter.WriteAttributeString('result', $TestSuiteInfo.resultMessage)
    $XmlWriter.WriteAttributeString('success', $TestSuiteInfo.success)
    $XmlWriter.WriteAttributeString('time',$TestSuiteInfo.totalTime)
    $XmlWriter.WriteAttributeString('asserts','0')

    if (-not $LegacyFormat)
    {
        $XmlWriter.WriteAttributeString('description', $TestSuiteInfo.Description)
    }
}

function Write-NUnitDescribeChildElements([object[]] $TestResults, [System.Xml.XmlWriter] $XmlWriter, [switch] $LegacyFormat, [string] $DescribeName)
{
    $suites = $TestResults | Group-Object -Property ParameterizedSuiteName

    foreach ($suite in $suites)
    {
        if ($suite.Name)
        {
            $suiteInfo = Get-TestSuiteInfo -TestSuiteGroup $suite

            $XmlWriter.WriteStartElement('test-suite')

            if (-not $LegacyFormat)
            {
                $suiteInfo.Name = "$DescribeName.$($suiteInfo.Name)"
            }

            Write-NUnitTestSuiteAttributes -TestSuiteInfo $suiteInfo -TestSuiteType 'ParameterizedTest' -XmlWriter $XmlWriter -LegacyFormat:$LegacyFormat

            $XmlWriter.WriteStartElement('results')
        }

        Write-NUnitTestCaseElements -TestResults $suite.Group -XmlWriter $XmlWriter -LegacyFormat:$LegacyFormat -DescribeName $DescribeName -ParameterizedSuiteName $suite.Name

        if ($suite.Name)
        {
            $XmlWriter.WriteEndElement()
            $XmlWriter.WriteEndElement()
        }
    }
}

function Write-NUnitTestCaseElements([object[]] $TestResults, [System.Xml.XmlWriter] $XmlWriter, [switch] $LegacyFormat, [string] $DescribeName, [string] $ParameterizedSuiteName)
{
    foreach ($testResult in $TestResults)
    {
        $XmlWriter.WriteStartElement('test-case')

        Write-NUnitTestCaseAttributes -TestResult $testResult -XmlWriter $XmlWriter -LegacyFormat:$LegacyFormat -DescribeName $DescribeName -ParameterizedSuiteName $ParameterizedSuiteName

        $XmlWriter.WriteEndElement()
    }
}

function Write-NUnitTestCaseAttributes($TestResult, [System.Xml.XmlWriter] $XmlWriter, [switch] $LegacyFormat, [string] $DescribeName, [string] $ParameterizedSuiteName)
{
    $testName = $TestResult.Name

    if (-not $LegacyFormat)
    {
        if ($testName -eq $ParameterizedSuiteName)
        {
            $paramString = ''
            if ($null -ne $TestResult.Parameters)
            {
                $params = @(
                    foreach ($value in $TestResult.Parameters.Values)
                    {
                        if ($null -eq $value)
                        {
                            'null'
                        }
                        elseif ($value -is [string])
                        {
                            '"{0}"' -f $value
                        }
                        else
                        {
                            #do not use .ToString() it uses the current culture settings 
                            #and we need to use en-US culture, which [string] or .ToString([Globalization.CultureInfo]'en-us') uses
                            [string]$value
                        }
                    }
                )

                $paramString = $params -join ','
            }

            $testName = "$testName($paramString)"
        }

        $testName = "$DescribeName.$testName"

        $XmlWriter.WriteAttributeString('description', $TestResult.Name)
    }

    $XmlWriter.WriteAttributeString('name', $testName)
    $XmlWriter.WriteAttributeString('executed', 'True')
    $XmlWriter.WriteAttributeString('time', (Convert-TimeSpan $TestResult.Time))
    $XmlWriter.WriteAttributeString('asserts', '0')
    $XmlWriter.WriteAttributeString('success', $TestResult.Passed)

    switch ($TestResult.Result)
    {
        Passed
        {
            $XmlWriter.WriteAttributeString('result', 'Success')
            break
        }
        Skipped
        {
            $XmlWriter.WriteAttributeString('result', 'Skipped')
            break
        }
        Pending
        {
            $XmlWriter.WriteAttributeString('result', 'Inconclusive')
            break
        }
        Failed
        {
            $XmlWriter.WriteAttributeString('result', 'Failure')
            $XmlWriter.WriteStartElement('failure')
            $xmlWriter.WriteElementString('message', $TestResult.FailureMessage)
            $XmlWriter.WriteElementString('stack-trace', $TestResult.StackTrace)
            $XmlWriter.WriteEndElement() # Close failure tag
            break
        }
    }
}
function Get-RunTimeEnvironment() {
    $osSystemInformation = (Get-WmiObject Win32_OperatingSystem)
    @{
        'nunit-version' = '2.5.8.0'
        'os-version' = $osSystemInformation.Version
        platform = $osSystemInformation.Name
        cwd = (Get-Location).Path #run path
        'machine-name' = $env:ComputerName
        user = $env:Username
        'user-domain' = $env:userDomain
        'clr-version' = [string]$PSVersionTable.ClrVersion
    }
}

function Exit-WithCode ($FailedCount) {
    $host.SetShouldExit($FailedCount)
}

function Get-ParentResult ($InputObject)
{
    #I am not sure about the result precedence, and can't find any good source
    #TODO: Confirm this is the correct order of precedence
    if ($inputObject.FailedCount  -gt 0) { return 'Failure' }
    if ($InputObject.SkippedCount -gt 0) { return 'Skipped' }
    if ($InputObject.PendingCount -gt 0) { return 'Inconclusive' }
    return 'Success'
}

function Get-GroupResult ($InputObject)
{
    #I am not sure about the result precedence, and can't find any good source
    #TODO: Confirm this is the correct order of precedence
    if ($InputObject |  Where {$_.Result -eq 'Failed'}) { return 'Failure' }
    if ($InputObject |  Where {$_.Result -eq 'Skipped'}) { return 'Skipped' }
    if ($InputObject |  Where {$_.Result -eq 'Pending'}) { return 'Inconclusive' }
    return 'Success'
}
