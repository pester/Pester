# In practice tests and your code are placed in two
# separate files. Tests belong in .Tests.ps1 file and code belongs
# in .ps1 file. Open the Get-Planet.ps1 file as well, please.


# You can run this test file by pressing F5, if your editor
# suports running powershell.

# You should see this output:
#    Describing Get-Planet
#    [+] Given no parameters, it lists all 8 planets 55ms
#
#    Context Filtering by Name
#      [+] Given valid -Name 'Earth', it returns 'Earth' 61ms
#      [+] Given valid -Name 'ne*', it returns 'Neptune' 11ms
#      [+] Given valid -Name 'ur*', it returns 'Uranus' 19ms
#      [+] Given valid -Name 'm*', it returns 'Mercury Mars' 9ms
#      [+] Given invalid parameter -Name 'Alpha Centauri', it returns $null 22ms


# First we need to import the Get-Planet.ps1 file to make the function
# Get-Planet available to our test. Notice the . at the start
# of the line.
$here = (Split-Path -Parent $MyInvocation.MyCommand.Path)
. $here\Get-Planet.ps1

# Normally we would use this PowerShell 3 and newer compatible
# version of the same code, but we need to keep our examples
# compatible with PowerShell v2.
# . $PSScriptRoot\Get-Planet.ps1


# Describe groups tests for easy navigation and overview.
# Usually we use the name of the function we are testing as description
# for our test group.
Describe 'Get-Planet' {

    # 'It' performs a single test. We write informative description
    # to tell others what is the result we expect. In this case
    # we expect that calling Get-Planet without any parameters will
    # return 8 items, because that is how many planets there are in our
    # solar system.
    It 'Given no parameters, it lists all 8 planets' {
        # In the body of the test we repeat what our description says,
        # but this time in code.

        # We call our Get-Planet function without any parameters
        # and store the result for later examination.
        $allPlanets = Get-Planet

        # We count how many planets we got. And validate it by using
        # the Should -Be assertion.
        $allPlanets.Count | Should -Be 8

        # The assertion will do nothing if the count is 8,
        # and throw an exception if the count is something else.
        # Yes, it is this simple: if ($count -ne 8) { throw "Count is wrong"}
    }

    # Context is the same as Describe, it groups our tests. Here we use
    # it to group tests for filtering planets by name.
    Context "Filtering by Name" {

        # We want our function to filter planets by name when -Name parameter is
        # provided, and we want it to support wildcards in the name, because that
        # is what most other functions do, and people expect this to be possible.


        # We could write many individual tests to test this functionality,
        # but most of them would be the same except for the data. So a better
        # option is to use TestCases to provide multiple sets of data for our test
        # but keep the body of the test the same. Pester then generates one test
        # for each test case, and injects our values in parameters.
        # This allows us to easily add more test cased as bugs start popping up, without
        # duplicating code.


        #There are three steps to make this work: description, parameters, and testcases.

        # We put names of our parameters in the description and surround them by <>.
        # Pester will expand test values into description, for example:
        # Given valid -Name 'ne*', it returns 'Neptune'
        It "Given valid -Name '<Filter>', it returns '<Expected>'" -TestCases @(

            # We define an array of hashtables. Each hashtable will be used
            # for one test.
            # @{ Filter = 'ne*'  ; Expected = 'Neptune' }
            # Every hashtable has keys named as our parameters, that is Filter and Expected.
            # And values that will be injected in our test, in this case 'ne*' and 'Neptune'.
            @{ Filter = 'Earth'; Expected = 'Earth' }
            @{ Filter = 'ne*'  ; Expected = 'Neptune' }
            @{ Filter = 'ur*'  ; Expected = 'Uranus' }
            @{ Filter = 'm*'   ; Expected = 'Mercury', 'Mars' }
        ) {

            # We define parameters in param (), to pass our test data into the test body.
            # Parameter names must align with key names in the hashtables.
            param ($Filter, $Expected)

            # We pass $Filter to -Name, for example 'ne*' in our second test.
            $planets = Get-Planet -Name $Filter
            # We validate that the returned name is equal to $Expected.
            # That is Neptune, in our second test.
            $planets | Select -ExpandProperty Name | Should -Be $Expected

            # again we are jumping thru hoops to keep PowerShell v2 compatibility
            # in PowerShell v3 you would just do this, as seen in readme:
            # $planets.Name | Should -Be $Expected
        }

        # Testing just the positive cases is usually not enough. Our tests
        # should also check that providing filter that matches no item returns
        # $null. We could merge this with the previous test but it is better to
        # split positive and negative cases, even if that means duplicated code.
        # Normally we would use TestCases here as well, but let's keep it simple
        # and show that Should -Be is pretty versatile in what it can assert.
        It "Given invalid parameter -Name 'Alpha Centauri', it returns `$null" {
            $planets = Get-Planet -Name 'Alpha Centauri'
            $planets | Should -Be $null
        }
    }
}

# Want to try it out yourself?

## Excercise 1:
# Add filter Population that returns planets with population larger
# or equal to the given number (in billions).
# Use 7.5 as the population of Earth. Use 0 for all other planets.

# Make sure to cover these test cases:
# - Population 7.5 returns Earth
# - Population 0 returns all planets
# - Population -1 returns no planets



# Excercise 2: Test that planets are returned in the correct order,
# from the one closest to the Sun.
# Make sure to cover these test cases:
# - Order of planets is correct when no filters are used.
# - Order of planets is correct when -Name filter is used.



# Excercise 3 (advanced): Add function that will list moons orbiting a given planet.
# - Make sure you can list all moons.
# - Make sure you can filter moons for given planet.
# - Make sure you Get-Planet and Get-Moon functions work together.
#   $moons = Get-Planet Earth | Get-Moon
#   $moons.Name | Should -Be Moon
