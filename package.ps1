
if (Test-Path "build") {
  Remove-Item "build" -Recurse -Force
}

mkdir build
vendor\tools\nuget pack Pester.nuspec -OutputDirectory build
