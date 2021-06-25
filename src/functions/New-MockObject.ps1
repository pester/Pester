function New-MockObject {
    <#
.SYNOPSIS
This function instantiates a .NET object from a type.

.DESCRIPTION
Using the New-MockObject you can mock an object based on .NET type.

An .NET assembly for the particular type must be available in the system and loaded.

.PARAMETER Type
The .NET type to create. This creates the object without calling any of its constructors or initializers. Use this to instantiate an object that does not have a public constructor. If your object has a constructor, or is giving you errors, try using the constructor and provide the object using the InputObject parameter to decorate it.

.PARAMETER InputObject
And already constucted object to decorate. Use New-Object or ::new to create it.

.PARAMETER Properties
Properties to define, specified as a hashtable, in format @{ PropertyName = value }.

.PARAMETER Methods
Methods to define, specified as a hashtable, in format @{ MethodName = scriptBlock }.

ScriptBlock can define param block, and it will recieve arguments that were provided to the function call based on order.

Method overloads are not supported because ScriptMethods are used to decorate the object, and ScriptMethods do not support method overloads.

For each method a property named _MethodName is defined which holds history of the invocations of the method and the arguments that were provided.

.EXAMPLE
```powershell
$obj = New-MockObject -Type 'System.Diagnostics.Process'
$obj.GetType().FullName
    System.Diagnostics.Process
```

.EXAMPLE
```powershell
$obj = New-MockObject -Type 'System.Diagnostics.Process' -Properties @{ Id = 123 }
```

.EXAMPLE
```powershell
$obj = New-MockObject -Type 'System.Diagnostics.Process' -Methods @{ Kill = { param($entireProcessTree) "killed" } }
$obj.Kill()
$obj.Kill($true)
$obj.Kill($false)

$obj._Kill

Call Arguments
---- ---------
   1 {}
   2 {True}
   3 {False}
```

.LINK
https://pester.dev/docs/commands/New-MockObject

.LINK
https://pester.dev/docs/usage/mocking

#>

    param (
        [Parameter(ParameterSetName = "Type", Mandatory)]
        [ValidateNotNullOrEmpty()]
        [type]$Type,
        [Parameter(ParameterSetName = "InputObject", Mandatory)]
        [ValidateNotNullOrEmpty()]
        $InputObject,
        [Parameter(ParameterSetName = "Type")]
        [Parameter(ParameterSetName = "InputObject")]
        [hashtable]$Properties,
        [Parameter(ParameterSetName = "Type")]
        [Parameter(ParameterSetName = "InputObject")]
        [hashtable]$Methods,
        [string] $MethodHistoryPrefix = "_"
    )

    $mock = if ($PSBoundParameters.ContainsKey("InputObject")) {
        $PSBoundParameters.InputObject
    }
    else {
        [System.Runtime.Serialization.Formatterservices]::GetUninitializedObject($Type)
    }

    if ($null -ne $Properties) {
        foreach ($property in $Properties.GetEnumerator()) {
            if ($mock.PSObject.Properties.Item($property.Key)) {
                $mock.PSObject.Properties.Remove($property.Key)
            }
            $mock.PSObject.Properties.Add([Pester.Factory]::CreateNoteProperty($property.Key, $property.Value))
            }
        }

        if ($null -ne $Methods) {
            foreach ($method in $Methods.GetEnumerator()) {
                $historyName = "$($MethodHistoryPrefix)$($method.Key)"
                if ($mock.PSObject.Properties.Item($historyName)) {
                    $mock.PSObject.Properties.Remove($historyName)
                }
                $mock.PSObject.Properties.Add([Pester.Factory]::CreateNoteProperty($historyName, [System.Collections.Generic.List[object]]@()))

                $saveHistoryAndInvokeUserScriptBlock = & {
                    # this new scriptblock ensures we only copy the variables here
                    # because closure only copies local variables, the scriptblock execution
                    # returns a scriptblock that is a closure

                    # save the provided scriptblock as $scriptblock in the closure
                    $scriptBlock = $method.Value
                    # save history name as $historyName in the closure
                    $historyName = $historyName
                    # save count as reference object so we can easily update the value
                    $count = @{ Count = 0 }

                    {
                        # before invoking user scriptblock up the counter by 1 and save args
                        $this.$historyName.Add([PSCustomObject] @{ Call = ++$count.Count; Arguments = $args })

                        # then splat the args, if user specifies parameters in the scriptblock they
                        # will get the values by order, same as if they called the script method
                        & $scriptBlock @args
                    }.GetNewClosure()
                }
                if ($mock.PSObject.Methods.Item($method.Key)) {
                    $mock.PSObject.Methods.Remove($method.Key)
                }

                $mock.PSObject.Methods.Add([Pester.Factory]::CreateScriptMethod($method.Key, $saveHistoryAndInvokeUserScriptBlock))
            }
        }

        $mock
    }
