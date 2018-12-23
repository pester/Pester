New-Module -Name m -ScriptBlock { 
    function import ($ScriptBlock) {

        # here I am dot-sourcing a scriptblock coming from a different scope
        # the dot-exexutes it in the target scope, same as with & but no extra scope 
        # is added, effectively keeping the variables in the place (this is well known 
        # not sure why I thought that . always imports in the current scope (in this case
        # it would be inside of our module))
        . $ScriptBlock
        "in module: $a"
    }

} | % { Get-Module $_.Name | Remove-Module; $_ | Import-Module  }

$sb = {

    $s = { $a = 1 }
    $b = { "-$a-" }
    $t = { "+$a+" }

    if ($null -ne $a ) { throw "`$a has value '$a', are the values leaking from previous session?"}
    if ($d) { 
        $s, $b, $t 
    }
    else {
        import $s
        "in script: $a"
        
        if ($null -eq $a) { throw "`$a is not in scope" }
        if (1 -ne $a) { throw "`$a has value '$a' but it should be 1"  }
    }
}

$d = $true
$r = &$sb
$d = $false
&$sb