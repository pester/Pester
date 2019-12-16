Pester can output test results to a XML file using the NUnit 2.5 schema.

## [TeamCity](https://www.jetbrains.com/teamcity/)

TeamCity includes (since v4.5) a bundled XML Test Reporting plugin that can interpret the Pester Test Results file and include the test results in TeamCity's build dashboard. Configuring Pester and TeamCity to "light up" the Pester results is easy.

### Pester Settings

#### Using ./bin/pester.bat

If you are using the Pester .bat file to run your tests, test results are automatically output to Test.Xml in the root of the TeamCity agent working Directory.

### Using Invoke-Pester

If you are not using the Pester .bat file and are instead calling Invoke-Pester directly from a build script, Make sure to specify a path using the `-OutputFile` and type include the "-OutputFormat" parameters. The path is relative to the TeamCity agent working directory.

```powershell
Invoke-Pester -OutputFile Test.xml -OutputFormat NUnitXml
```

### TeamCity Settings

1. In your TeamCity build configuration settings, go to the "Build Step" page.
1. Add the "XML Report Processing" Build Feature.
1. The Report Type should be set to NUnit. You can select version 2.5.0.
1. In the Monitoring Rules text box, enter the xml file path given to Pester's `-OutputXml` parameter. If you use the Pester.bat file, simply enter Test.xml.

#### TeamCity Troubleshooting

In some deployments of TeamCity it may be necessary to specify the Powershell version to use in the Invoke-Pester build-step -- specifying "5.1" has been observed to work.

If Pester does not seem to be available from your PowerShell build-step, here is an example on how to install it on-the-fly: https://david-obrien.net/2016/01/continuous-integration-with-teamcity-powershell-and-git/

### Code Coverage

Code coverage metrics are not included in the NUnit xml report so it is necessary to pass them to TeamCity separately using a PassThru variable and the [Build Interaction feature](https://confluence.jetbrains.com/display/TCD8/Build+Script+Interaction+with+TeamCity#BuildScriptInteractionwithTeamCity-ReportingBuildStatistics).

```powershell
$testResults = Invoke-Pester -OutputFile Test.xml -OutputFormat NUnitXml -CodeCoverage (Get-ChildItem -Path $PSScriptRoot\*.ps1 -Exclude *.Tests.* ).FullName -PassThru
Write-Output "##teamcity[buildStatisticValue key='CodeCoverageAbsLTotal' value='$($testResults.CodeCoverage.NumberOfCommandsAnalyzed)']"
Write-Output "##teamcity[buildStatisticValue key='CodeCoverageAbsLCovered' value='$($testResults.CodeCoverage.NumberOfCommandsExecuted)']"
```

## [AppVeyor](appveyor.com)

The concept is the same: you serialize test results as `NUnitXml` and then upload them to the CI test reporting system.

Your [`appveyor.yml`](https://www.appveyor.com/docs/appveyor-yml) can contain section like this

```yaml
test_script:
    - ps: |
        $testResultsFile = ".\TestsResults.xml"
        $res = Invoke-Pester -OutputFormat NUnitXml -OutputFile $testResultsFile -PassThru
        (New-Object 'System.Net.WebClient').UploadFile("https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)", (Resolve-Path $testResultsFile))
        if ($res.FailedCount -gt 0) {
            throw "$($res.FailedCount) tests failed."
        }
```

**Note**: `if` check with `throw` is used to fail the build, if any tests are failing.

**Note**: If tests write anything to the pipeline, then `$res` object will contain it as well.  Be careful!

**That's it! May all your tests be green!**

## [Azure DevOps](https://azure.microsoft.com/en-us/solutions/devops/)

With Azure DevOps the concept is very similar again, you run pester then publish the results back to Azure DevOps. This can be done through a YAML configuration or through tasks run on the agent in the build pipeline.

An example of a PowerShell script to run against a single pester test file.

```powershell
# This updates pester not always necessary but worth noting
Install-Module -Name Pester -Force -SkipPublisherCheck

Import-Module Pester

Invoke-Pester -Script $(System.DefaultWorkingDirectory)\MyFirstModule.test.ps1 -OutputFile $(System.DefaultWorkingDirectory)\Test-Pester.XML -OutputFormat NUnitXML
```

Then add a Publish Test Results task, it is important to change the Test Result format to NUnit to allow Azure DevOps to ingest the output file.

**Note** Using the Azure PowerShell task doesn't require you to enable the control option of "Continue on error" before the publish test results. If you use one of the Pester Marketplace tools your mileage may vary.
