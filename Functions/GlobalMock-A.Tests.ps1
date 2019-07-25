Set-StrictMode -Version Latest

# This script exists to create and mock a global function, then exit.  The actual behavior
# that we need to test is covered in GlobalMock-B.Tests.ps1, where we make sure that the
# global function was properly restored in its scope.

$functionName = '01c1a57716fe4005ac1a7bf216f38ad0'

if (Test-Path Function:\$functionName) {
    Remove-Item Function:\$functionName -Force -ErrorAction Stop
}

function global:01c1a57716fe4005ac1a7bf216f38ad0 {
    return 'Original Function'
}

function script:Testing {
    return 'Script scope'
}

Describe 'Mocking Global Functions - Part One' {
    Mock $functionName {
        return 'Mocked'
    }

    It 'Mocks the global function' {
        & $functionName | Should -Be 'Mocked'
    }
}
