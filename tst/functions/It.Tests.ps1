Set-StrictMode -Version Latest

Describe 'Testing It' {
    It 'Throws when missing name' {
        { It {

            'something'
            }
        } | Should -Throw -ExpectedMessage 'Test name has multiple lines and no test scriptblock is provided*'
    }

    It 'Throws when missing scriptblock' {
        { It 'runs a test'
            {
                # This scriptblock is a new statement as scriptblock didn't start on It-line nor used a backtick
            }
        } | Should -Throw -ExpectedMessage 'No test scriptblock is provided*'
    }

    It 'Throws when provided unbound scriptblock' {
        # Unbound scriptblocks would execute in Pester's internal module state
        { It 'i' -Test ([scriptblock]::Create('')) } | Should -Throw -ExpectedMessage 'Unbound scriptblock*'
    }
}
