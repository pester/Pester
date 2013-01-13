$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\Describe.ps1"

Describe -Tags "It" "It" {

    It "does not pollute the global namespace" {
      $current_globals_count = $(Get-Variable).Count
      $current_globals_count.should.be($pester.globals_count)
    }

}

