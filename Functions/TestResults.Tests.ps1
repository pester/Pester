function Test-Xml($inputFile, $schemaFile, $Namespace = "http://www.w3.org/2001/XMLSchema" ) {
    BEGIN {
        $failCount = 0
        $failureMessages = ""
        $fileName = ""
    }

    PROCESS {
        $fileName = $inputFile.FullName
        $readerSettings = New-Object -TypeName System.Xml.XmlReaderSettings
        $readerSettings.ValidationType = [System.Xml.ValidationType]::Schema
        $readerSettings.ValidationFlags = [System.Xml.Schema.XmlSchemaValidationFlags]::ProcessInlineSchema -bor
            [System.Xml.Schema.XmlSchemaValidationFlags]::ProcessSchemaLocation -bor 
            [System.Xml.Schema.XmlSchemaValidationFlags]::ReportValidationWarnings
        $readerSettings.Schemas.Add($Namespace, $SchemaFile) | Out-Null
        $readerSettings.add_ValidationEventHandler(
        {
            $failureMessages = $failureMessages + [System.Environment]::NewLine + $fileName + " - " + $_.Message
            $failCount = $failCount + 1
        });
        $reader = [System.Xml.XmlReader]::Create($inputFile, $readerSettings)
        while ($reader.Read()) { }
        $reader.Close()
    }

    END {
        $failureMessages
        "$failCount validation errors were found"
    }
}

Describe "Write test results" {
    Setup -Dir "Results"

    It "should write a successful test result" {
        $testResults = @{}
        $testResults.Tests = @(
               @{
                    testNumber = 1
                    name = "Successful testcase"
                    time = "1.0"
                    failure_message = ""
                    success = $true
                }; );

        $testFile = "$TestDrive\Results\Tests.xml"
        Write-NunitTestReport $testResults $testFile
        $xmlResult = [xml] (Get-Content $testFile)
        $xmlTestCase = $xmlResult.'test-results'.'test-case'
        $xmlTestCase.name.Should.Be("Successful testcase")
        $xmlTestCase.result.Should.Be("Success")
        $xmlTestCase.time.Should.Be("1.0")
        Test-Xml $testFile ".\nunit_schema_2.5.xsd"
    }

    It "should write a failed test result" {
        $testResults = @{}
        $testResults.Tests = @(
               @{
                    testNumber = 1
                    name = "Failed testcase"
                    time = "2.0"
                    failureMessage = 'Assert failed: "Expected: Test. But was: Testing"';
                    stackTrace = 'at line: 28 in  C:\Pester\Result.Tests.ps1'
                    success = $false
                }; );

        $testFile = "$TestDrive\Results\Tests.xml"
        Write-NunitTestReport $testResults $testFile
        $xmlResult = [xml] (Get-Content $testFile)
        $xmlTestCase = $xmlResult.'test-results'.'test-case'
        $xmlTestCase.name.Should.Be("Failed testcase")
        $xmlTestCase.result.Should.Be("Failure")
        $xmlTestCase.time.Should.Be("2.0")
        $xmlTestCase.failure.message.Should.Be('Assert failed: "Expected: Test. But was: Testing"');
        $xmlTestCase.failure.'stack-trace'.should.be('at line: 28 in  C:\Pester\Result.Tests.ps1')

        Test-Xml $testFile ".\nunit_schema_2.5.xsd"
    }

     It "should write the test summary" {
        $testResults = @{}
        $testResults.Tests = @( "" );
        $testResults.FailedTests = @("", "")
        $testResults.runDate =  "01-01-2012"
        $testResults.runTime = "00:10:10"

        $testFile = "$TestDrive\Results\Tests.xml"
        Write-NunitTestReport $testResults $testFile
        $xmlResult = [xml] (Get-Content $testFile)
        $xmlTestResult = $xmlResult.'test-results'
        $xmlTestResult.total.Should.Be(1)
        $xmlTestResult.failures.Should.Be(2)
        $xmlTestResult.date.Should.Be("01-01-2012")
        $xmlTestResult.time.Should.Be("00:10:10")

        Test-Xml $testFile ".\nunit_schema_2.5.xsd"
    }

}
