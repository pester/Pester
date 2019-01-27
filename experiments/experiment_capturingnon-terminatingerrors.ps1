get-module m,n,p | remove-module

# some tested code
New-Module m -ScriptBlock {

    New-Module n -ScriptBlock {
        function a { Write-Error "error abcd" }
    } | Import-Module

    function b {
        a
    }
} | Import-Module

$sb = {
    # errors are collected only when
    # this has cmdletbinding
    [CmdletBinding()]
    param()

    b
}

# this wants to collect the
# errors of the incoming code
New-Module p -ScriptBlock {
    function i {
        [CmdletBinding()]
        param (
            $ScriptBlock
        )

        &$ScriptBlock -ErrorVariable f

        [PsCustomObject]@{
            Errors = $f
        }
    }
} | Import-Module

i $sb
