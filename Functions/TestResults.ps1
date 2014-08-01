function Get-HumanTime($Seconds) {
    if($Seconds -gt 0.99) {
        $time = [math]::Round($Seconds, 2)
        $unit = "s"
    }
    else {
        $time = [math]::Floor($Seconds * 1000)
        $unit = "ms"
    }
    return "$time$unit"
}

function GetFullPath ([string]$Path) {
    $fullpath = Resolve-Path -Path $Path -ErrorAction SilentlyContinue -ErrorVariable Error
    if ($fullpath)
    {
        $fullpath
    }
    else
    {
        $error[0].TargetObject
    }
}

function Export-NUnitReport {
    param (
        [parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [PSObject]$InputObject,
        [parameter(Mandatory=$true)]
        [String]$Path
    )

    #the xmlwriter create method can resolve relatives paths by itself. but its current directory might
    #be different from what PowerShell sees as the current directory so I have to resolve the path beforehand
    #working around the limitations of Resolve-Path
    $Path = GetFullPath -Path $Path

    # Create The Document
    $settings = New-Object -TypeName Xml.XmlWriterSettings
    $settings.Indent = $true
    $settings.NewLineOnAttributes = $false
    try {
        $XmlWriter = [Xml.XmlWriter]::Create($Path,$settings)

        # Write the XML Declaration
        $XmlWriter.WriteStartDocument($false)

        # Write Root Element
        $xmlWriter.WriteStartElement("test-results")
        $XmlWriter.WriteAttributeString("xmlns","xsi", $null, "http://www.w3.org/2001/XMLSchema-instance")
        $XmlWriter.WriteAttributeString("xsi","noNamespaceSchemaLocation", [Xml.Schema.XmlSchema]::InstanceNamespace , "nunit_schema_2.5.xsd")
        $XmlWriter.WriteAttributeString("name","Pester")
        $XmlWriter.WriteAttributeString("total", $InputObject.TotalCount)
        $XmlWriter.WriteAttributeString("errors", "0")
        $XmlWriter.WriteAttributeString("failures", $InputObject.FailedCount)
        $XmlWriter.WriteAttributeString("not-run", "0")
        $XmlWriter.WriteAttributeString("inconclusive", "0")
        $XmlWriter.WriteAttributeString("ignored", "0")
        $XmlWriter.WriteAttributeString("skipped", "0")
        $XmlWriter.WriteAttributeString("invalid", "0")
        $date = Get-Date
        $XmlWriter.WriteAttributeString("date", (Get-Date -Date $date -Format "yyyy-MM-dd"))
        $XmlWriter.WriteAttributeString("time", (Get-Date -Date $date -Format "HH:mm:ss"))

        #Write environment information
        $XmlWriter.WriteStartElement("environment")
        $environment = Get-RunTimeEnvironment
        $environment.GetEnumerator() | foreach {
            $XmlWriter.WriteAttributeString($_.Name, $_.Value)
        }
        $XmlWriter.WriteEndElement() #Close the Environment tag

        #Write culture information
        $XmlWriter.WriteStartElement("culture-info")
        $XmlWriter.WriteAttributeString("current-culture", ([System.Threading.Thread]::CurrentThread.CurrentCulture).Name)
        $XmlWriter.WriteAttributeString("current-uiculture", ([System.Threading.Thread]::CurrentThread.CurrentUiCulture).Name)
        $XmlWriter.WriteEndElement() #Close culture-info tag

        #Write root test-suite element containing all the describes
        $XmlWriter.WriteStartElement("test-suite")
        $XmlWriter.WriteAttributeString("type", "Powershell")
        $XmlWriter.WriteAttributeString("name", $InputObject.Path)
        $XmlWriter.WriteAttributeString("executed", "True")

        $isSuccess = $inputObject.FailedCount -eq 0
        $result = if ($isSuccess) { "Success" }  else { "Failure"}
        $XmlWriter.WriteAttributeString("result", $result)
        $XmlWriter.WriteAttributeString("success",[string]$isSuccess)
        $XmlWriter.WriteAttributeString("time",(Convert-TimeSpan $InputObject.Time))
        $XmlWriter.WriteAttributeString("asserts","0")
        $XmlWriter.WriteStartElement("results")

        $Describes = $InputObject.TestResult | Group -Property Describe
        $Describes | foreach {
            $currentDescribe = $_
            $DescribeInfo = Get-TestSuiteInfo $currentDescribe

            #Write test suites
            $XmlWriter.WriteStartElement("test-suite")

            $XmlWriter.WriteAttributeString("type", "Powershell")
            $XmlWriter.WriteAttributeString("name", $DescribeInfo.name)
            $XmlWriter.WriteAttributeString("executed", "True")
            $XmlWriter.WriteAttributeString("result", $DescribeInfo.resultMessage)
            $XmlWriter.WriteAttributeString("success", $DescribeInfo.success)
            $XmlWriter.WriteAttributeString("time",$DescribeInfo.totalTime)
            $XmlWriter.WriteAttributeString("asserts","0")
            $XmlWriter.WriteStartElement("results")

            #Write test-results
            $currentDescribe.Group | foreach {
                $XmlWriter.WriteStartElement("test-case")
                $XmlWriter.WriteAttributeString("name", $_.Name)
                $XmlWriter.WriteAttributeString("executed", "True")
                $XmlWriter.WriteAttributeString("time", (Convert-TimeSpan $_.Time))
                $XmlWriter.WriteAttributeString("asserts", "0")
                $XmlWriter.WriteAttributeString("success", $_.Passed)
                if ($_.Passed)
                {
                    $XmlWriter.WriteAttributeString("result", "Success")
                }
                else
                {
                    $XmlWriter.WriteAttributeString("result", "Failure")
                    $XmlWriter.WriteStartElement("failure")
                    $xmlWriter.WriteElementString("message", $_.FailureMessage)
                    $XmlWriter.WriteElementString("stack-trace", $_.StackTrace)
                }
                $XmlWriter.WriteEndElement() #Close test-case tag
            }

            $XmlWriter.WriteEndElement() #Close results tag
            $XmlWriter.WriteEndElement() #Close test-suite tag
        }

        $XmlWriter.WriteEndElement() #Close results tag
        $XmlWriter.WriteEndElement() #Close test-suite tag

        $XmlWriter.WriteEndElement() #Close the test-result tag

        $XmlWriter.Flush()
    }
    finally
    {
        if ($XmlWriter) {
            #make sure the writer is closed, otherwise it keeps the file locked
            try { $xmlWriter.Close() } catch {}
        }
    }
}

function Get-TestSuiteInfo ($DescribeGroup) {
    $suite = @{
        resultMessage = "Failure"
        success = "False"
        totalTime = "0.0"
        name = $DescribeGroup.name
    }

    #calculate the time first, I am converting the time into string in the TestCases
    $suite.totalTime = (Get-TestTime $DescribeGroup.Group)
    $suite.success = (Get-TestSuccess $DescribeGroup.Group)
    if($suite.success -eq "True")
    {
        $suite.resultMessage = "Success"
    }
    $suite
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
            "0"
        }
    }
}
function Get-TestTime($tests) {
    [TimeSpan]$totalTime = 0;
    if ($tests)
    {
        $tests | foreach {
            $totalTime += $_.time
        }
    }
    $totalTime | Convert-TimeSpan
}

function Get-TestSuccess($tests) {
    #if any fails, the whole suite fails
    $result = $true
    $tests | foreach {
        if (-not $_.Passed) {
            $result = $false
        }
    }
    [String]$result
}

function Get-RunTimeEnvironment() {
    $osSystemInformation = (Get-WmiObject Win32_OperatingSystem)
    @{
        "nunit-version" = "2.5.8.0"
        "os-version" = $osSystemInformation.Version
        platform = $osSystemInformation.Name
        cwd = (Get-Location).Path #run path
        "machine-name" = $env:ComputerName
        user = $env:Username
        "user-domain" = $env:userDomain
        "clr-version" = $PSVersionTable.ClrVersion.ToString()
    }
}

function Exit-WithCode ($FailedCount) {
    $host.SetShouldExit($FailedCount)
}
