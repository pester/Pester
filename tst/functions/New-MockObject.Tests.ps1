Set-StrictMode -Version Latest

describe 'New-MockObject' {

    it 'instantiates an object from a class with no public constructors' {
        $type = 'Microsoft.PowerShell.Commands.Language'
        New-MockObject -Type $type | should -beoftype $type
    }
}

Describe 'New-MockObject-With-Properties' {
    # System.Diagnostics.Process.Id is normally read only, using the
    # Properties switch in New-MockObject should allow us to mock these.
    it 'Fails with just a normal mock' {
        $mockedProcess = New-MockObject -Type 'System.Diagnostics.Process'

        { $mockedProcess.Id = 123 } | Should -Throw
    }

    it 'Works when you mock the property' {
        $mockedProcess = New-MockObject -Type 'System.Diagnostics.Process' -Properties @{Id = 123 }

        $mockedProcess.Id | Should -Be 123
    }

    it 'Should preserve types' {
        $mockedProcess = New-MockObject -Type 'System.Diagnostics.Process' -Properties @{Id = 123 }
        $mockedProcess.Id | Should -BeOfType [int]
    }
}
