function write-debug{
[CmdletBinding()]
 param (
    [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
    [Alias('Msg')]
    [AllowEmptyString()]
    [System.String]
    ${Message}
 )

    $functionName = $MyInvocation.MyCommand.Name
write-host "$functionName Called"
    $global:mockCallHistory += @{CommandName=$functionName;BoundParams=$PSBoundParameters; Args=$args}
    $mock=$mockTable.$functionName
    $idx=$mock.blocks.Length
    while(--$idx -ge 0) {
write-host "trying $functionName"
        if(&($mock.blocks[$idx].Filter) @args @PSBoundParameters) {
write-host "$functionName verified"
            $mock.blocks[$idx].Verifiable=$false
            &($mockTable.$functionName.blocks[$idx].mock) @args @PSBoundParameters
write-host "$functionName mock called"
            return
        }
    }
    write-host "calling original $functionName"
    &($mock.OriginalCommand) @args @PSBoundParameters
write-host "original $functionName called"
}