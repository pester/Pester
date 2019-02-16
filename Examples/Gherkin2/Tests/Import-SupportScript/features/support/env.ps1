$Script:EnvScriptLoaded = $True
$Script:EnvScriptLoadedBeforeOtherScripts = !($Script:HooksLoaded -or $Script:Support1Loaded -or $Script:Support2Loaded)