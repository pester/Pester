Describe "Replacing strings" {
    It "should escape powershell backtick when replacing strings" {
        $replacments = Get-ReplacementArgs "@@test@@" @{ test = "This is a test don``t do this" }
        $replacments.should.be("-replace '@@test@@', 'This is a test dont do this'")

    }

    It "should escape single quote when replacing strings" {
        $replacments = Get-ReplacementArgs "@@test@@" @{ test = "This is a test don't do this" }
        $replacments.should.be("-replace '@@test@@', 'This is a test dont do this'")
    }
}

Describe "Write nunit test results" {
    Setup -Dir "Results"
    $nunitSchema = (Convert-Path ".\nunit_schema_2.5.xsd")

    It "should write a successful test result" {
        $testResults = @{}
        $testResults.Categories = @( 
            @{
                name = 'Mocked Category'
                Tests = @(
                @{
                    testNumber = 1
                    name = "Successful testcase"
                    time = "1.0"
                    failure_message = ""
                    success = $true
                }; );
            }
        );

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
        $testResults.Categories = @( 
            @{
                name = 'Mocked Category'
                Tests = @(
                @{
                    testNumber = 1
                    name = "Failed testcase"
                    time = "2.0"
                    failureMessage = 'Assert failed: "Expected: Test. But was: Testing"';
                    stackTrace = 'at line: 28 in  C:\Pester\Result.Tests.ps1'
                    success = $false
                }; );
            }
        );

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
        $testResults.Categories = @( 
            @{
                name = 'Mocked Category'
                Tests = @( @{
                    name = "Testcase"
                    time = "1.0"
                    success = $true
                }; );
            }
        );
        $testFile = "$TestDrive\Results\Tests.xml"
        Write-NunitTestReport $testResults $testFile
        $xmlResult = [xml] (Get-Content $testFile)
        $xmlTestResult = $xmlResult.'test-results'
        $xmlTestResult.total.Should.Be(0)
        $xmlTestResult.failures.Should.Be(0)
        $xmlTestResult.date.Should.Be($true)
        $xmlTestResult.time.Should.Be($true)
    }

    it "should write the test-suite information" {
        $testResults = @{}
        $testResults.Categories = @( 
            @{
            name = 'Mocked Category'
            Tests = @(
                @{
                    name = "Successful testcase"
                    time = "1.0"
                    success = $true
                },
                @{
                    name = "Successful testcase"
                    time = "1.1"
                    success = $true
                };);
            }
        );
        $testFile = "$TestDrive\Results\Tests.xml"
        Write-NunitTestReport $testResults $testFile
        $xmlResult = [xml] (Get-Content $testFile)
        
        $xmlTestResult = $xmlResult.'test-results'.'test-suite'
        $xmlTestResult.type.Should.Be("Powershell")
        $xmlTestResult.name.Should.Be("Mocked Category")
        $xmlTestResult.result.Should.Be("Success")
        $xmlTestResult.success.Should.Be("True")
        $xmlTestResult.time.Should.Be(2.1)
    }

    it "should write the test-suite information for different test suites" {
        $testResults = @{}
        $testResults.Tests = @(
            @{
                name = "Successful testcase"
                time = "1.0"
                success = $true
                category = "foo"
            },
            @{
                name = "Successful testcase"
                time = "1.1"
                success = $true
                category = "bar"
            };
        );
        $testFile = "$TestDrive\Results\Tests.xml"
        Write-NunitTestReport $testResults $testFile
        $xmlResult = [xml] (Get-Content $testFile)
        
        $xmlTestResult = $xmlResult.'test-results'.'test-suite'
    }

    it "should write the environment information" {
        $testResults = @{}
        $testResults.Tests = @( "" );
        $testFile = "$TestDrive\Results\Tests.xml"
        Write-NunitTestReport $testResults $testFile
        $xmlResult = [xml] (Get-Content $testFile)

        $xmlEnvironment = $xmlResult.'test-results'.'environment'
        $xmlEnvironment.'os-Version'.Should.Be($true) #check if exists
        $xmlEnvironment.platform.Should.Be($true)
    }
}

