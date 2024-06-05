# Copies shared csharp files from Profiler module, which is expected to be
# in a folder named Profiler next to Pester repo folder.

$ErrorActionPreference = 'Stop'
$profilerPath = "$PSScriptRoot\..\..\..\Profiler"

if (-not (Test-Path $profilerPath)) {
    throw "Profiler module not found at '$profilerPath'."
}


$commit = git -C $profilerPath log --format="%h %B" -n 1
$branch = git -C $profilerPath branch --show-current
$profilerSources = "$profilerPath\csharp\Profiler"
$pesterSources = "$PSScriptRoot\Pester\Tracing\"
$names = @(
    "ExternalTracerAdapter.cs"
    "ITracer.cs"
    "Tracer.cs"
    "TracerHostUI.cs"
)
foreach ($name in $names ) {
    $destination = "$pesterSources\$name"
    Copy-Item -Path "$profilerSources\$name" -Destination $destination -Force
    $content = Get-Content $destination -Raw
    $n = [System.Environment]::NewLine
    ("// Copied from Profiler module, branch: $branch, commit: $commit$n$n" + $content) | Set-Content $destination -NoNewline
}
