function Mock ([string]$function, [ScriptBlock]$mockWith, [switch]$verifiable, [HashTable]$parameterFilters = @{})
{
    # If verifiable, add to a verifiable hashtable
    # Rename existing function
    # Create New Function to invoke Script Block
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