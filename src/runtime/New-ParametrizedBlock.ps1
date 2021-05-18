function New-ParametrizedBlock {
    param (
        [Parameter(Mandatory = $true)]
        [String] $Name,
        [Parameter(Mandatory = $true)]
        [ScriptBlock] $ScriptBlock,
        [int] $StartLine = $MyInvocation.ScriptLineNumber,
        [String[]] $Tag = @(),
        [HashTable] $FrameworkData = @{ },
        [Switch] $Focus,
        [String] $Id,
        [Switch] $Skip,
        $Data
    )

    foreach ($d in @($Data)) {
        # shallow clone to give every block it's own copy
        $fmwData = $FrameworkData.Clone()
        New-Block -Name $Name -ScriptBlock $ScriptBlock -StartLine $StartLine -Tag $Tag -FrameworkData $fmwData -Focus:$Focus -Skip:$Skip -Data $d
    }
}
