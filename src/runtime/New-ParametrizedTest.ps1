function New-ParametrizedTest () {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [String] $Name,
        [Parameter(Mandatory = $true, Position = 1)]
        [ScriptBlock] $ScriptBlock,
        [int] $StartLine = $MyInvocation.ScriptLineNumber,
        [String[]] $Tag = @(),
        # do not use [hashtable[]] because that throws away the order if user uses [ordered] hashtable
        [object[]] $Data,
        [Switch] $Focus,
        [Switch] $Skip
    )

    # using the position of It as Id for the the test so we can join multiple testcases together, this should be unique enough because it only needs to be unique for the current block, so the way to break this would be to inline multiple tests, but that is unlikely to happen. When it happens just use StartLine:StartPosition
    # TODO: I don't think the Id is needed anymore
    $id = $StartLine
    foreach ($d in $Data) {
        New-Test -Id $id -Name $Name -Tag $Tag -ScriptBlock $ScriptBlock -StartLine $StartLine -Data $d -Focus:$Focus -Skip:$Skip
    }
}
