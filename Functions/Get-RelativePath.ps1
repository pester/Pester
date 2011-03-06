function Get-RelativePath {
<#
.SYNOPSIS
   Get a path to a file (or folder) relative to another folder
.DESCRIPTION
   Converts the FilePath to a relative path rooted in the specified Folder
.PARAMETER Folder
   The folder to build a relative path from
.PARAMETER FilePath
   The File (or folder) to build a relative path TO
.PARAMETER Resolve
   If true, the file and folder paths must exist
.Example
   Get-RelativePath ~\Documents\WindowsPowerShell\Logs\ ~\Documents\WindowsPowershell\Modules\Logger\log4net.xslt
   
   ..\Modules\Logger\log4net.xslt
   
   Returns a path to log4net.xslt relative to the Logs folder
#>
[CmdletBinding()]
param(
   [Parameter(Mandatory=$true, Position=0)]
   [string]$Folder
, 
   [Parameter(Mandatory=$true, Position=1, ValueFromPipelineByPropertyName=$true)]
   [Alias("FullName")]
   [string]$FilePath
,
   [switch]$Resolve
)
process {
   Write-Verbose "Resolving paths relative to '$Folder'"
   $from = $Folder = split-path $Folder -NoQualifier -Resolve:$Resolve
   $to = $filePath = split-path $filePath -NoQualifier -Resolve:$Resolve

   while($from -and $to -and ($from -ne $to)) {
      if($from.Length -gt $to.Length) {
         $from = split-path $from
      } else {
         $to = split-path $to
      }
   }

   $filepath = $filepath -replace "^"+[regex]::Escape($to)+"\\"
   $from = $Folder
   while($from -and $to -and $from -gt $to ) {
      $from = split-path $from
      $filepath = join-path ".." $filepath
   }
   Write-Output $filepath
}
}

