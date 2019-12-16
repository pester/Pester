`New-MockObject` is a Pester function (introduced in Pester 3.4.4) that allows you to create "fake" objects of almost any type to run in Pester mocks. These "fake objects" allow your mocks to return the same type as the function it was mocking to pass the result to entities that are strongly typed.

To explain the problem that `New-MockObject` solves, we'll describe a scenario that cannot be solved without it. I'm working with a script that contains two functions.

### Do-Thing.ps1

```powershell
    function Set-Thing {
        param (
            [Thing.Type]$Thing ## $Thing is STRONGLY typed. This param MUST be Thing.Type
        )

        ## Stuff that does something to thing here
    }

    function Get-Thing {
        param (
            [string]$ThingLabel
        )

        [Thing.Type]::Get($ThingLabel) ## Must return an object of Thing.Type
    }

    $thing = Get-Thing -ThingLabel 'whatever'
    Set-Thing -Thing $thing ## Requires $thing to be of type Thing.Type
```

This script gets and sets a thing based on a `ThingLabel` string parameter. It uses the `Get-Thing` function and the parameter value to get a particular thing. Then, it uses its `Set-Thing` function to change the thing. Most importantly, Get-Thing returns a [Thing.Type] object that Set-Thing requires as input.

A sample Pester test for the script might look something like this. To isolate the Set-Thing function, we mock the output of the Get-Thing function. Then, we assert that Set-Thing is called once.

```powershell
    Describe 'Set the thing' {

        Mock 'Get-Thing' {
            [pscustomobject]@{ Property = 'Value' }
        }

        Mock 'Set-Thing'

        .\Do-Thing.ps1

        It 'sets the right thing' {
            $assertMockParams = @{
                'CommandName' = 'Set-Thing'
                'Times' = 1
                'Exactly' = $true
                'ParameterFilter' = {$Thing -eq '????' }
            }
            Assert-MockCalled @assertMockParams
        }
    }
```

The assertion (Assert-MockCalled on Set-Thing) fails because the `Thing` parameter of `Set-Thing` must be of type `Thing.Type` and `Get-Thing` must return that type. But, instead, the mock of `Get-Thing` returns a custom object (`[System.Management.Automation.PSCustomObject]`).

The solution is to change the `Get-Thing` mock to return a `Thing.Type` object. But, this can be very difficult. The `New-Object` cmdlet works only when the class has public constructors (methods for creating a new object of this type). Even when the class has public constructors, the arguments that the constructors require might be objects that don't have public constructors or they might be very complex to create.

Even when the object you initially set out to mock and all of the arguments have public constructors and you manage to create this object, not all objects have public constructors. Some only have private constructors that are not even possible to create with `New-Object`! There's got to be a better way. Lucky for us, there is now with `New-MockObject`.

`New-MockObject` does not rely on constructors. It instead creates "fake" objects that look just like the original that use constructors. Once created, these "fake" objects can be passed to anything that requires a particular object type, and it will never know the difference. This means that it's now possible to create Pester tests for this scenario using `New-MockObject`.

The only part that would need to be changed is the mock to `Get-Thing`. Now, depending on if the required .NET assembly is available; you can simply mock `Get-Thing` to output whatever type of object you want regardless of the circumstances.

```powershell
    mock 'Get-Thing' {
        New-MockObject -Type Thing.Type
    }
```

At this point, the test would run as you would expect!
