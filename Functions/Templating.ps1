function Get-ReplacementArgs($template, $data) {
  if ( $data.GetType().Name -ne 'HashTable' ) 
	{
		$data = $data.PsObject.Properties | foreach { $hash=@{}} { $hash.($_.Name) = $_.Value } { $hash } 
	}
	$data.keys | %{
      $name = $_
			$value = $data.$_ -replace "``", "" -replace "`'", ""
			if($template -match "@@$name@@") {
          "-replace '@@$name@@', '$value'"
      }
  }
}

function Get-Template($fileName) {
  	#TODO removed the external dependency on $Global:ModulePath here, but is the following line the best way to determine the path?
		$modulePath = ( Get-Module -Name Pester ).Path | Split-Path
		
		$path = $ModulePath + '\templates'
    
    return Get-Content ("$path\$filename")
}

function Invoke-Template($templatName, $data) {
    $template = Get-Template $templatName
    $replacments = Get-ReplacementArgs $template $data
    return Invoke-Expression "`$template $replacments"
}
