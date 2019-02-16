# This variable should never be set within the scope of
# the executing tests because this file should never be loaded
# as part of the environment (through Import-Environment)
$Script:SupportLoaded = $True