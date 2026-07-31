# The context object returned by New-ShouldAssertion. It is a PowerShell class, defined in
# Pester's module, on purpose:
#
#   * Its methods keep Pester's module session state, so they reach the internal assertion
#     helpers (input collection, message formatting, the shared failure path) while those
#     helpers stay hidden from the assertion author's scope -- even when the custom assertion
#     lives in another module.
#   * Unlike a script method added with Add-Member, a class method does not re-wrap an
#     exception thrown out of it. That is essential for Fail(): the terminating error keeps its
#     exact 'PesterAssertionFailed' identity, which Pester's output and the soft-assertion
#     machinery rely on.
#   * Constructing a class instance is much cheaper than building an object with several
#     Add-Member calls, which matters because an assertion may run many thousands of times.
#
# Method bodies call Pester's internal functions directly (Collect-Input, Get-AssertionMessage,
# ...). Those are Pester's own commands, not the external commands guarded by $SafeCommands, so
# they are called by name.
class ShouldAssertion {
    [System.Management.Automation.PSCmdlet] $Caller
    [object[]] $Buffer = @()
    [bool] $IsPipelineInput
    # The collected input is kept inside a hashtable (the shape Collect-Input returns) and is only
    # ever read back through $this.Collected['Actual']. This is deliberate: a value that wraps an
    # IEnumerable -- for example a Deserialized.System.Data.DataTable produced by Import-Clixml --
    # is silently enumerated by PowerShell when it is read out of a plain [object] field or passed
    # through a class method parameter, which replaces the single object with its items. Collecting
    # the input inside the New-ShouldAssertion *function* (not a method) and holding it as a
    # hashtable value preserves it exactly, the same way Collect-Input itself does.
    [hashtable] $Collected = @{ Actual = $null; IsPipelineInput = $false }
    [string] $Expecting = 'Scalar'

    ShouldAssertion([System.Management.Automation.PSCmdlet] $caller) {
        $this.Caller = $caller
        # $PSCmdlet.MyInvocation.ExpectingInput mirrors $MyInvocation.ExpectingInput inside the
        # assertion, so the author does not have to pass $MyInvocation separately.
        $this.IsPipelineInput = [bool] $caller.MyInvocation.ExpectingInput
    }

    # Returns the value to assert on -- collected from either the pipeline or the -Actual parameter
    # by New-ShouldAssertion -- with its shape preserved (a one-item collection stays a collection).
    # The collection happens once, in the function; this is only the safe accessor.
    [object] Actual() {
        return $this.Collected['Actual']
    }

    # Reports a failure. Whether it throws immediately or records the failure and lets the test
    # continue (a soft assertion) is decided by the caller's -ErrorAction or the
    # Should.ErrorAction configuration, exactly like the built-in assertions.
    [void] Fail([string] $Message) {
        $this.Fail($Message, @{}, $false)
    }

    [void] Fail([string] $Message, [System.Collections.IDictionary] $Data) {
        $this.Fail($Message, $Data, $false)
    }

    # $Pretty formats the expected and actual values across multiple lines, matching the built-in
    # assertions that compare complex values (Should-BeEquivalent and the empty/whitespace string
    # assertions).
    [void] Fail([string] $Message, [System.Collections.IDictionary] $Data, [bool] $Pretty) {
        if ($null -eq $Data) { $Data = @{} }

        $expected = $Data['Expected']
        # When the author does not pass an explicit Actual, reuse the value collected for this
        # assertion so <actual> in the message shows what was really tested. Read it through the
        # hashtable (never a plain field) to avoid enumerating IEnumerable-wrapping values, and
        # assign in separate statements rather than `$actual = if (...) { ... } else { ... }`,
        # because using the if as an expression sends the value through the output stream, which
        # unwraps a single-item collection (e.g. @(5)) down to a scalar.
        if ($Data.Contains('Actual')) {
            $actual = $Data['Actual']
        }
        else {
            $actual = $this.Collected['Actual']
        }
        $because = [string] $Data['Because']

        # Everything except the three special keys becomes a <key> token in the message.
        $extra = @{}
        foreach ($key in $Data.Keys) {
            if ($key -ne 'Expected' -and $key -ne 'Actual' -and $key -ne 'Because') {
                $extra[$key] = $Data[$key]
            }
        }

        $formattedMessage = Get-AssertionMessage -Expected $expected -Actual $actual -Because $because -Data $extra -DefaultMessage $Message -Pretty:$Pretty

        $hint = $this.Hint()
        if ($hint) { $formattedMessage = "$formattedMessage`n`nHint: $hint" }

        Invoke-AssertionFailed -Message $formattedMessage -CallerCmdlet $this.Caller
    }

    # Returns the diagnostic input hint (or $null), for assertions that want to inspect it before
    # deciding how to fail. Fail() already appends it automatically.
    [object] Hint() {
        return (Get-AssertionGotcha -Cmdlet $this.Caller -Buffer $this.Buffer -CollectedActual $this.Collected['Actual'] -IsPipelineInput $this.IsPipelineInput -Expecting $this.Expecting)
    }

    # Formats a value the same way Pester does in assertion messages.
    [string] Format([object] $Value) {
        return (Format-Nicely2 -Value $Value)
    }

    # Returns $Expected unchanged, or throws when it is a collection. Guards assertions that only
    # make sense against a single value.
    [object] EnsureScalar([object] $Expected) {
        return (Ensure-ExpectedIsNotCollection $Expected)
    }

    # Returns whether a value is treated as a collection.
    [bool] IsCollection([object] $Value) {
        return (Is-Collection -Value $Value)
    }
}

function New-ShouldAssertion {
    <#
    .SYNOPSIS
    Creates the assertion helper object used to author custom `Should-*` assertions.

    .DESCRIPTION
    `New-ShouldAssertion` returns a small helper object (conventionally stored in `$assert`)
    that gives a custom assertion the same building blocks the built-in `Should-*` assertions
    use: pipeline input collection, consistent value formatting, diagnostic input hints, and
    the shared failure path that powers soft assertions.

    Call it once at the top of your assertion, passing the assertion's own `$PSCmdlet`, its
    `-Actual` value and `$Input`, then use the returned object's methods:

    - `Actual()` returns the value to assert on, collected from either the pipeline or the
      `-Actual` parameter. The `-As` parameter (`Scalar` (default), `ExactType`, `Collection`
      or `CollectionItems`) selects both unrolling and the wording of the input hint.
    - `Fail(message [, data])` reports a failure. `message` may contain `<expected>`,
      `<actual>`, `<expectedType>`, `<actualType>`, `<because>` and any `<key>` present in
      `data`. `data` is a hashtable whose `Expected`, `Actual` and `Because` entries are
      treated specially; all other entries become message tokens. Whether this throws
      immediately or records the failure and continues (a soft assertion) is decided by the
      caller's `-ErrorAction` or the `Should.ErrorAction` configuration, exactly like the
      built-in assertions.
    - `Hint()` returns the diagnostic input hint (or `$null`), for assertions that need to
      inspect it before deciding how to fail.
    - `Format(value)` formats a value the same way Pester does in assertion messages.
    - `EnsureScalar(expected)` returns `expected` unchanged, or throws when it is a collection,
      guarding assertions that only make sense against a single value.
    - `IsCollection(value)` returns whether a value is treated as a collection.

    A passing result is implicit: an assertion passes simply by returning without calling `Fail()`.
    There is nothing to call at the end, and custom assertions still work inside a mock
    `-ParameterFilter` automatically.

    .PARAMETER Caller
    The `$PSCmdlet` of the assertion function. Used to reach the caller's session state (so
    soft assertions and the mock parameter filter behave correctly) and to recover the
    original pipeline input for hints.

    .PARAMETER Actual
    The assertion's `-Actual` value. Pass it even when the value usually arrives from the
    pipeline; it is `$null` in that case and the pipeline `$Input` is used instead.

    .PARAMETER Buffer
    The assertion function's `$Input`. Holds the values received from the pipeline. Pass
    `$Input` even when the assertion is usually called with `-Actual`; it is empty in that case.

    .PARAMETER As
    How the input is collected: `Scalar` (default) and `ExactType` unroll a single piped value,
    `Collection` and `CollectionItems` keep it as a collection. The value also selects the
    wording of the diagnostic hint shown when the assertion fails; use `None` for an assertion
    that compares the whole input structurally (like `Should-BeEquivalent`) and so has no
    input-shape gotcha to hint about.

    .EXAMPLE
    ```powershell
    function Should-BeAwesome {
        [CmdletBinding()]
        param (
            [Parameter(ValueFromPipeline)] $Actual,
            [Parameter(Position = 0)]      $Expected = 'Awesome',
            [string] $Because
        )
        end {
            $assert = New-ShouldAssertion -Caller $PSCmdlet -Actual $Actual -Buffer $Input
            $Actual = $assert.Actual()

            if ($Actual -ne $Expected) {
                $assert.Fail(
                    'Expected <expected>,<because> but got <actual>.',
                    @{ Expected = $Expected; Because = $Because })
            }
        }
    }

    'lame' | Should-BeAwesome
    ```

    Defines and uses a custom assertion. Because it goes through the shared failure path, it
    supports `-Because`, soft assertions via `-ErrorAction`, and mock parameter filters for free.

    .EXAMPLE
    ```powershell
    # A shared helper backing several of your own assertions. Thread the calling assertion's own
    # $PSCmdlet and $Input into New-ShouldAssertion so pipeline detection, the input hint and the
    # soft/hard -ErrorAction decision all resolve against the real assertion -- no matter how many
    # wrapper layers sit in between.
    function Invoke-MyEquals {
        param ([System.Management.Automation.PSCmdlet] $Cmdlet, $Actual, $Buffer, $Expected)

        $assert = New-ShouldAssertion -Caller $Cmdlet -Actual $Actual -Buffer $Buffer
        $value = $assert.Actual()
        if ($value -ne $Expected) {
            $assert.Fail('Expected <expected> but got <actual>.', @{ Expected = $Expected })
        }
    }

    function Should-Equal {
        [CmdletBinding()]
        param ([Parameter(ValueFromPipeline)] $Actual, [Parameter(Position = 0)] $Expected)
        end { Invoke-MyEquals -Cmdlet $PSCmdlet -Actual $Actual -Buffer $Input -Expected $Expected }
    }
    ```

    Factors common assertion logic into one helper reused by several `Should-*` assertions. Nothing
    keys off the assertion's *name*, so the helper does not need to know which assertion called it;
    everything keys off the single `$PSCmdlet` you pass as `-Caller`. Passing the user-facing
    assertion's `$PSCmdlet` and `$Input` down keeps the input hint, pipeline detection and
    `-ErrorAction` behaviour identical to an unwrapped assertion, at any wrapping depth.

    .LINK
    https://pester.dev/docs/commands/New-ShouldAssertion

    .LINK
    https://pester.dev/docs/assertions

    .LINK
    https://pester.dev/docs/commands/Should-Be
    #>
    [CmdletBinding()]
    [OutputType([ShouldAssertion])]
    param (
        [Parameter(Mandatory, Position = 0)]
        [System.Management.Automation.PSCmdlet] $Caller,

        [Parameter(Position = 1)]
        [AllowNull()]
        [object] $Actual,

        [Parameter(Position = 2)]
        [AllowNull()]
        [object[]] $Buffer,

        [ValidateSet('Scalar', 'ExactType', 'Collection', 'CollectionItems', 'None')]
        [string] $As = 'Scalar'
    )

    [ShouldAssertion] $assertion = [ShouldAssertion]::new($Caller)
    # Store the pipeline buffer with a property assignment rather than passing it through the
    # constructor. Passing a single-item [object[]] whose one item is $null to a method or
    # constructor parameter unwraps it to $null, which would silently drop a legitimate one-item
    # ($null) collection (e.g. `$null | Should-BeCollection @()`). Property assignment keeps the
    # array intact. When -Buffer is omitted the field keeps its empty-array default.
    if ($null -ne $Buffer) {
        $assertion.Buffer = $Buffer
    }
    $assertion.Expecting = $As

    # Collect the input here, in the function, and never in a class method: passing a value that
    # wraps an IEnumerable (e.g. a deserialized DataTable) through a class method parameter makes
    # PowerShell enumerate it and replace the single object with its items. A function parameter
    # does not, so the value reaches Collect-Input -- and the returned hashtable -- intact.
    # Single-value assertions (Scalar/ExactType) and structural ones (None) unroll a lone piped
    # item; only the collection kinds keep the pipeline input as a collection.
    $unroll = $As -ne 'Collection' -and $As -ne 'CollectionItems'
    $assertion.Collected = Collect-Input -ParameterInput $Actual -PipelineInput $assertion.Buffer -IsPipelineInput $assertion.IsPipelineInput -UnrollInput:$unroll
    $assertion.IsPipelineInput = $assertion.Collected['IsPipelineInput']

    # Success is implicit: an assertion "passes" simply by not calling Fail(), so the author never
    # has to signal a pass. In a normal run this produces no output; inside a mock -ParameterFilter
    # it emits $true on the assertion's own pipeline (via its $PSCmdlet) so the filter matches,
    # exactly like the built-in assertions.
    #
    # This is done here, in the function, and deliberately not in a class method. On Windows
    # PowerShell 5.1 a class method whose object was built for a caller in another module does not
    # run in the class's (Pester's) session state, so $Caller.WriteObject($true) does not reach the
    # filter and an imported assertion never matches. New-ShouldAssertion always runs in Pester's
    # module scope, and $Caller is the assertion's real $PSCmdlet, so the emit is reliable on every
    # supported PowerShell. Emitting up front is safe: if the assertion then calls Fail() the
    # terminating error propagates out of the mock filter before this value is read (see Mock.ps1,
    # `$result = & $wrapper`), discarding it.
    if (Set-AssertionPassResult) {
        $Caller.WriteObject($true)
    }
    $assertion
}
