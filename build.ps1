if (-not (Test-Path 'variable:PSPesterRoot')) {
    $workTree = @(git rev-parse --git-path $PSScriptRoot --is-inside-work-tree)
    # this is not a mistake it returns a 'true' string
    if (0 -lt $workTree.Count -and 'true' -eq $workTree[-1]) {
        $root = Resolve-Path (@(git rev-parse --git-path $PSScriptRoot --show-toplevel)[-1])
        Set-Variable -Name PSPesterRoot -Value $root.Path -Option Constant -Scope Global -Force
    }
}
