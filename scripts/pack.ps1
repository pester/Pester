$commitCount = (git log --oneline).count
$version = "1.0.4.$commitCount"
nuget pack Pester.nuspec -version $version
cp *.nupkg C:\NuGetPackages