# This file is invoked as a real script file by Invoke-InNewScriptScope to push a new
# script scope into the caller's session state (see src/Pester.Runtime.ps1).
#
# Do NOT rename it to Pester.ps1. PSResourceGet treats a '<ModuleName>.ps1' file in the
# package (i.e. Pester.ps1) as a script and prints a spurious installation-path warning
# on Install-PSResource Pester. See https://github.com/pester/Pester/issues/2826.
param ($ScriptBlock)

. $ScriptBlock

