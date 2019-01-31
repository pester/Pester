[Collections.Stack] $script:scopeStack = New-Object 'Collections.Stack'

function Reset-Scope {
    $script:scopeStack.Clear()
}

function New-Scope ([string]$Name, [string]$Hint, [string]$Id = [Guid]::NewGuid().ToString('N')) {
    [PSCustomObject] @{
        Id   = $Id
        Name = $Name
        Hint = $Hint
    }
}

function Push-Scope ($Scope) {
    $script:scopeStack.Push($Scope)
}

function Pop-Scope {
    $script:scopeStack.Pop()
}

function Get-Scope ($Scope = 0) {
    if ($Scope -eq 0) {
        $script:scopeStack.Peek()

    }
}

function Get-ScopeHistory {
    $history = $script:scopeStack.ToArray()
    [Array]::Reverse($history)
    $history
}