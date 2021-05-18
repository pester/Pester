function New-FilterObject {
    [CmdletBinding()]
    param (
        [String[]] $FullName,
        [String[]] $Tag,
        [String[]] $ExcludeTag,
        [String[]] $Line
    )

    [PSCustomObject] @{
        FullName   = $FullName
        Tag        = $Tag
        ExcludeTag = $ExcludeTag
        Line       = $Line
    }
}
