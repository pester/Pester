function Mock ([string]$function, [ScriptBlock]$mockWith, [switch]$verifiable, [HashTable]$parameterFilters = @{})
{
    # If verifiable, add to a verifiable hashtable
    if(!(Test-Path Function:\$function)){ Throw "Could not find function $function"}
    Rename-Item Function:\$function script:PesterIsMocking_$function
    Set-Item Function:\script:$function -value $mockWith
    # Mocked function should redirect to real function if param filters are not met
    # param filters are met, mark in the verifiable table
}

function Assert-VerifiableMocks {
    # Check that the Verifiables have all been called
    # if not, throw
}

function Clear-Mocks {
    # Called at the end of Describe
    # Clears the Verifiable table
    # Renames all renamed mocks back to original names
}