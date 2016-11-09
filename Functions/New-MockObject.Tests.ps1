describe 'New-MockObject' {

    . .\New-MockObject.ps1
    
    it 'instantiates an object from a class with no public constructors' {
        $type = 'Microsoft.PowerShell.Commands.Language'
        New-MockObject -Type $type | should beoftype $type
    }

}
