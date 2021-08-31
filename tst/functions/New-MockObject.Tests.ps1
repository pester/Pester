﻿Set-StrictMode -Version Latest

Describe 'New-MockObject' {

    It 'instantiates an object from a class with no public constructors' {
        $type = 'Microsoft.PowerShell.Commands.Language'
        New-MockObject -Type $type | Should -BeOfType $type
    }

    It 'Add a property to existing object' {
        $o = New-Object -TypeName 'System.Diagnostics.Process'
        $mockObject = New-MockObject -InputObject $o -Properties @{ Id = 123 }

        $mockObject | Should -Be $o
        $mockObject.Id | Should -Be 123
    }

    It 'User scriptblock can use $this to reference to itself' {
        $o = [PSCustomObject]@{
            Name = 'Jakub'
        }

        $mockObject = New-MockObject -InputObject $o -Methods @{ GetName = {
                $this.Name
            }
        }

        $mockObject | Should -Be $o
        $mockObject.Name | Should -Be 'Jakub'
        $mockObject.GetName() | Should -Be 'Jakub'
    }

    Context 'Methods' {
        It "Adds a method to the object" {
            $o = New-Object -TypeName 'System.Diagnostics.Process'
            $mockObject = New-MockObject -InputObject $o -Methods @{ Kill = { param() "killed" } }

            $mockObject | Should -Be $o
            $mockObject.Kill() | Should -Be "killed"
        }

        It "Counts history of the invocation" {
            $o = New-Object -TypeName 'System.Diagnostics.Process'
            $mockObject = New-MockObject -InputObject $o -Methods @{ Kill = { param($entireProcessTree) "killed" } }

            $mockObject | Should -Be $o
            $mockObject.Kill() | Should -Be "killed"
            $mockObject._Kill[-1].Call | Should -Be 1
            $mockObject._Kill[-1].Arguments | Should -Be $null
            $mockObject.Kill($true) | Should -Be "killed"
            $mockObject._Kill[-1].Call | Should -Be 2
            $mockObject._Kill[-1].Arguments | Should -Be $true
        }

        It "Adds 2 methods to the object" {
            $mockObject = New-MockObject -Type 'Net.Sockets.TcpClient' -Methods @{
                Connect = { param($Server, $Port)"connect" };
                Close   = { param($Server, $Port)"close" }
            }

            $mockObject.Connect() | Should -Be "connect"
            $mockObject.Close() | Should -Be "close"
        }
    }


    Context 'Modifying readonly-properties' {
        # System.Diagnostics.Process.Id is normally read only, using the
        # Properties switch in New-MockObject should allow us to mock these.
        it 'Fails with just a normal mock' {
            $mockedProcess = New-MockObject -Type 'System.Diagnostics.Process'

            { $mockedProcess.Id = 123 } | Should -Throw
        }

        it 'Works when you mock the property' {
            $mockedProcess = New-MockObject -Type 'System.Diagnostics.Process' -Properties @{ Id = 123 }

            $mockedProcess.Id | Should -Be 123
        }

        it 'Should preserve types' {
            $mockedProcess = New-MockObject -Type 'System.Diagnostics.Process' -Properties @{Id = 123 }
            $mockedProcess.Id | Should -BeOfType [int]
        }
    }
}
