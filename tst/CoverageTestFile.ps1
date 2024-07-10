# assignment needs to be shifted to the correct line and column
# of parent, unless there is an if
$a = 10
$a = ((10))
$g = if ($a -eq 10) { "yes" } else { "no" }

$b = (Start-Sleep 0)

if ($a -eq 10) {
    $b
}

$h = @{
    name = 10
    age  = (start-sleep 1)
    mmm  = if ($a -eq 10) { "yes" } else { "no" }
}
Start-Sleep 0

$h = @{
    a = @{
        b = @{
            c = 10
        }
    }
}

# return needs to be shifted by 7 chars to right (length of 'return'+1)
function a () {
    $text = "some text"
    return ($Text.ToUpper() -replace 'a', 'b')
}

a

# pipeline
@("aaa") | ForEach-Object -Process {
    "b"
}


# while
$a = 0
$f = 1..10
$i = 1
$o = while ($a -lt 10) {
    $a = 11
    $m = $f[$i]
    $a++
}

# for
$l = 1..10
for ($i = 0; $i -lt $l.Count; $i++) {
    $l[$i]
}


# foreach
$a = 10
foreach ($k in 1..2) {
    $m = $a -contains $k
}


function f () { "aaa" }
function g {
    param(
        # we report this correctly as covered, but the old CC reports it as uncovered
        # $a = ("a"),
        $b = "b",
        # ps4 reports this incorrectly
        $Options = ((& {
                    f
                })) # ,
        # we report this correctly as "no" is not covered but the bp based CC reports it as covered
        # $Options2 = ((& {
        #             if ($true) { "yes" } else { "no" }
        #         }))
    )
    $Options
}
g


# switch, without special treatment this is hoitsing too high
$selector = switch ("hashtable") {
    "Hashtable" { 1 }
    Default { throw "Unsupported path selector." }
}

# # switch, this actually looks like a bug in the current breakpoint based CC
# # when you return a scriptblock, the scriptblock is marked as
# # not executed, but since that is a literal we surely executed it
# # enabling this reports more lines in the CC than the breakpoint based CC and fails the test
# # do not enable it until we are 100% sure that we are covering all the breakpoint
# # based use cases. This is a double edged sword, marking code that was not covered as
# # covered is a bad thing (even though this is not the case and seems like a real bug.)
# $selector = switch ("hashtable") {
#     "Hashtable" { { param($InputObject) $InputObject } }
#     Default { throw "Unsupported path selector." }
# }

function Get-Error ($err) { $err }
try {
    $a = 10
    throw "a"
}
catch {
    $errorThrown = $true
    $err = Get-Error $_
}
finally {
    $aaa = $true
}

$findIf = $true
while ($findIf) {
    [string]$PartialText = "AAA"
    $findIf = $false
}
