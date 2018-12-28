try {

    throw "aaa"
}
catch { 
    $ErrorActionPreference = 'stop'
   throw $_ 
}

