Describe "Write nunit test results" {
    Setup -Dir "Results"
    $nunitSchema = (Convert-Path ".\nunit_schema_2.5.xsd")
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
        $xmlTestCase = $xmlResult.'test-results'.'test-suite'.'results'.'test-case'
        $xmlTestCase.name.Should.Be("Successful testcase")
        $xmlTestCase.result.Should.Be("Success")
        $xmlTestCase.time.Should.Be("1.0")
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
        $xmlTestCase = $xmlResult.'test-results'.'test-suite'.'results'.'test-case'
        $xmlTestCase.name.Should.Be("Failed testcase")
        $xmlTestCase.result.Should.Be("Failure")
        $xmlTestCase.time.Should.Be("2.0")
        $xmlTestCase.failure.message.Should.Be('Assert failed: "Expected: Test. But was: Testing"');
        $xmlTestCase.failure.'stack-trace'.should.be('at line: 28 in  C:\Pester\Result.Tests.ps1')

    }

     It "should write the test summary" {
        $testResults = @{}
        $testResults.Tests = @( "" );
        $testResults.FailedTests = @("", "")

        $testFile = "$TestDrive\Results\Tests.xml"
        Write-NunitTestReport $testResults $testFile
        $xmlResult = [xml] (Get-Content $testFile)
        $xmlTestResult = $xmlResult.'test-results'
        $xmlTestResult.total.Should.Be(1)
        $xmlTestResult.failures.Should.Be(2)
        $xmlTestResult.date.Should.Be($true)
        $xmlTestResult.time.Should.Be($true)

    }

    it "should write the test-suite information" {
        $testResults = @{}
        $testResults.Tests = @(
            @{
                name = "Successful testcase"
                time = "1.0"
                success = $true
            },
            @{
                name = "Successful testcase"
                time = "1.1"
                success = $true
            };
        );
        $testFile = "$TestDrive\Results\Tests.xml"
        Write-NunitTestReport $testResults $testFile
        $xmlResult = [xml] (Get-Content $testFile)
        
        $xmlTestResult = $xmlResult.'test-results'.'test-suite'
        $xmlTestResult.type.Should.Be("Powershell")
        $xmlTestResult.name.Should.Be("Pester")
        $xmlTestResult.result.Should.Be("Success")
        $xmlTestResult.success.Should.Be("True")
        $xmlTestResult.time.Should.Be(2.1)
    }

    
    # it "should write the environment information" {
    #     $testResults = @{}
    #     $testResults.Tests = @( "" );
    #     $testResults.Environment = @{
    #         osVersion = "Windows 7";
    #         platform = "Windows"
    #         runPath = "C:\workspace\Pester\"
    #         machineName = "Computer1"
    #         userName = "foo"
    #     };
    #     $testFile = "$TestDrive\Results\Tests.xml"
    #     Write-NunitTestReport $testResults $testFile
    #     $xmlResult = [xml] (Get-Content $testFile)

    #     $xmlEnvironment = $xmlResult.'test-results'.'environment'
    #     $xmlEnvironment.'os-Version'.Should.Be("Windows 7")
    #     $xmlEnvironment.platform.Should.Be("Windows")
    #     $xmlEnvironment.runPath.Should.Be("C:\workspace\Pester\")
    #     $xmlEnvironment.machineName.Should.Be("Computer1")
    #     $xmlEnvironment.userName.Should.Be("foo")
    # }
}

