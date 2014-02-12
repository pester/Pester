$root = Split-Path -parent $MyInvocation.MyCommand.Definition
$fileWatcherAssemblyPath = Resolve-Path "$root\Talifun.FileWatcher.dll"

[Reflection.Assembly]::LoadFile($fileWatcherAssemblyPath)

function Start-AutoTest {
	param(
		[string]$folderToWatch = ".",
        [switch]$useSameWindow = $false,
		[string]$includeFilter = ".+?\.(ps1|psm1)$",
		[string]$excludeFilter = "",
		[int]$pollTime = 500,
		[switch]$includeSubdirectories = $true,
        [switch]$runAtStartup = $true
	)

    $folderToWatch = Resolve-Path $folderToWatch

    if($useSameWindow.isPresent) {
    	$watcher = new-object Talifun.FileWatcher.EnhancedFileSystemWatcher($folderToWatch, $includeFilter, $excludeFilter, $pollTime, $includeSubdirectories.isPresent) 

        $parameters = @{RunAtStartup=$runAtStartup.isPresent;}

    	Register-ObjectEvent $watcher -EventName FileFinishedChangingEvent -MessageData $parameters -Action { param($sender, $eventArgs) 
            
            if (!((!$event.MessageData.RunAtStartup -and $eventArgs.ChangeType -eq [Talifun.FileWatcher.FileEventType]::InDirectory) -or $eventArgs.ChangeType -eq [Talifun.FileWatcher.FileEventType]::Deleted))
            {        
                $filePath = $eventArgs.FilePath

                if(!$filePath.EndsWith(".tests.ps1", [System.StringComparison]::InvariantCultureIgnoreCase)) {
                    $filePath = [regex]::Replace($filePath, "\.psm?1", ".tests.ps1")
                }

                if (Test-Path $filePath)
                {
                    cls
                    Write-Host "We are going to run - $($eventArgs.FilePath) and type is $($eventArgs.ChangeType)"
                    Invoke-Pester $filePath
                }
            }
    	} | Out-Null

        $watcher.Start()
    }
    else
    {
        $PesterModulePath = (Get-Command Invoke-Pester).Module.Path
        $AutoTestModulePath = (Get-Command Start-AutoTest).Module.Path
        $startup = "`"ipmo $PesterModulePath;ipmo $AutoTestModulePath; Start-AutoTest`""

        Start-Process `
            -FilePath "powershell" `
            -WorkingDirectory $folderToWatch `
            -ArgumentList "-NonInteractive -NoExit -Command $startup -useSameWindow"
    }
}

