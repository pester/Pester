
function Test-NullOrWhiteSpace ($Value) {
    # psv2 compatibility, on newer .net we would simply use
    # [string]::isnullorwhitespace
    $null -eq $Value -or $Value -match "^\s*$"
}

function Get-Type ($InputObject) {
    try {
        $ErrorActionPreference = 'Stop'
        # normally this would not ever throw
        # but in psv2 when datatable is deserialized then
        # [Deserialized.System.Data.DataTable] does not contain
        # .GetType()
        $InputObject.GetType()
    }
    catch [Exception] {
        return [Object]
    }

}
