Set-StrictMode -Version Latest

InPesterModuleScope {
    Describe 'Code Coverage Analysis' {
        BeforeAll {
            function Clear-WhiteSpace ($Text) {
                # clear whitespace in formatted xml so we can keep the XML in the test file
                # formatted and easily see changes in source control
                "$($Text -replace "(`t|`n|`r)"," " -replace "\s+"," " -replace "\s*<","<" -replace ">\s*", ">")".Trim()
            }

            $root = (Get-PSDrive TestDrive).Root

            $rootSubFolder = Join-Path -Path $root -ChildPath TestSubFolder
            $null = New-Item -Path $rootSubFolder -ItemType Directory -ErrorAction SilentlyContinue

            $testScriptPath = Join-Path -Path $root -ChildPath TestScript.ps1
            $testScript2Path = Join-Path -Path $root -ChildPath TestScript2.ps1
            $testScript3Path = Join-Path -Path $rootSubFolder -ChildPath TestScript3.ps1

            $null = New-Item -Path $testScriptPath -ItemType File -ErrorAction SilentlyContinue

            Set-Content -Path $testScriptPath -Value @'
                function FunctionOne
                {
                    function NestedFunction
                    {
                        'I am the nested function.'
                        'I get fully executed.'
                    }

                    if ($true)
                    {
                        'I am functionOne'
                        NestedFunction
                    }

                    if ($false) { 'I cannot get called.' }

                    Invoke-Command { 'I get called.' }
                }

                function FunctionTwo
                {
                    'I am function two.  I never get called.'
                }

                FunctionOne

'@
            # Classes have been introduced in PowerShell 5.0
            if ($PSVersionTable.PSVersion.Major -ge 5) {
                Add-Content -Path $testScriptPath -Value @'

                class MyBaseClass {
                    MyBaseClass()
                    {
                        'I am the constructor of base class.'
                    }
                }

                class MyClass : MyBaseClass
                {
                    MyClass() : base()
                    {
                        'I am the constructor.'
                    }

                    MethodOne()
                    {
                        'I am method one.'
                    }

                    hidden static MethodTwo()
                    {
                        'I am method two. I never get called.'
                    }
                }

                $class = [MyClass]::new()
                $class.MethodOne()

'@
            }
            else {
                # Before that, let's just create equivalent commands to above class with exact same line numbers
                Add-Content -Path $testScriptPath -Value @'

                #class MyBaseClass {
                    function MyBaseClass
                    {
                        'I am the constructor of base class.'
                    }
                #}

                #class MyClass
                #{
                    function MyClass
                    {
                        MyBaseClass # call the base constructor
                    }

                    function MethodOne
                    {
                        'I am method one.'
                    }

                    function MethodTwo
                    {
                        'I am method two. I never get called.'
                    }
                #}

                MyClass
                MethodOne

'@
            }

            $null = New-Item -Path $testScript2Path -ItemType File -ErrorAction SilentlyContinue

            Set-Content -Path $testScript2Path -Value @'
                'Some {0} file' `
                    -f `
                    'other'

'@

            $null = New-Item -Path $testScript3Path -ItemType File -ErrorAction SilentlyContinue

            Set-Content -Path $testScript3Path -Value @'
            'Some {0} file' `
                -f `
                'other'

'@
        }

        Context 'Entire file measured using <description>' -Foreach @(
            @{ UseBreakpoints = $true; Description = "breakpoints" }
            @{ UseBreakpoints = $false; Description = "Profiler based cc" }
        ) {
            BeforeAll {
                # TODO: renaming, breakpoints mean "code point of interests" in most cases here, not actual breakpoints
                # Path deliberately duplicated to make sure the code doesn't produce multiple breakpoints for the same commands
                $breakpoints = Enter-CoverageAnalysis -CodeCoverage $testScriptPath, $testScriptPath, $testScript2Path, $testScript3Path -UseBreakpoints $UseBreakpoints

                @($breakpoints).Count | Should -Be 19 -Because 'it has the proper number of breakpoints defined'

                $sb = {
                    $null = & $testScriptPath
                    $null = & $testScript2Path
                    $null = & $testScript3Path
                }

                if ($UseBreakpoints) {
                    # with breakpoints
                    & $sb
                }
                else {
                    $patched, $tracer = Start-TraceScript $breakpoints
                    try { & $sb } finally { Stop-TraceScript -Patched $patched }
                    $measure = $tracer.Hits
                }

                $coverageReport = Get-CoverageReport -CommandCoverage $breakpoints -Measure $measure
            }

            It 'Reports the proper number of executed commands' {
                $coverageReport.NumberOfCommandsExecuted | Should -Be 16
            }

            It 'Reports the proper number of analyzed commands' {
                $coverageReport.NumberOfCommandsAnalyzed | Should -Be 19
            }

            It 'Reports the proper number of analyzed files' {
                $coverageReport.NumberOfFilesAnalyzed | Should -Be 3
            }

            It 'Reports the proper number of missed commands' {
                $coverageReport.MissedCommands.Count | Should -Be 3
            }

            It 'Reports the correct missed command' {
                $coverageReport.MissedCommands[0].Command | Should -Be "'I cannot get called.'"
                $coverageReport.MissedCommands[1].Command | Should -Be "'I am function two.  I never get called.'"
                $coverageReport.MissedCommands[2].Command | Should -Be "'I am method two. I never get called.'"
            }

            It 'Reports the proper number of hit commands' {
                $coverageReport.HitCommands.Count | Should -Be 16
            }

            It 'Reports the correct hit command' {
                $coverageReport.HitCommands[0].Command | Should -Be "'I am the nested function.'"
            }

            It 'Reports the correct class names' {
                $coverageReport.HitCommands[0].Class | Should -BeNullOrEmpty
                # Classes have been introduced in PowerShell 5.0
                if ($PSVersionTable.PSVersion.Major -ge 5) {
                    $coverageReport.HitCommands[9].Class | Should -Be 'MyBaseClass'
                    $coverageReport.HitCommands[10].Class | Should -Be 'MyClass'
                    $coverageReport.MissedCommands[2].Class | Should -Be 'MyClass'
                }
                else {
                    $coverageReport.HitCommands[9].Class | Should -BeNullOrEmpty
                    $coverageReport.MissedCommands[2].Class | Should -BeNullOrEmpty
                }
            }

            It 'Reports the correct function names' {
                $coverageReport.HitCommands[0].Function | Should -Be 'NestedFunction'
                $coverageReport.HitCommands[2].Function | Should -Be 'FunctionOne'
                $coverageReport.HitCommands[9].Function | Should -Be 'MyBaseClass'
                $coverageReport.HitCommands[10].Function | Should -Be 'MyClass'
                $coverageReport.MissedCommands[2].Function | Should -Be 'MethodTwo'
            }

            It 'JaCoCo report must be correct' {
                [String]$jaCoCoReportXml = Get-JaCoCoReportXml -CommandCoverage $breakpoints -TotalMilliseconds 10000 -CoverageReport $coverageReport -Format "JaCoCo"
                $jaCoCoReportXml = $jaCoCoReportXml -replace 'Pester \([^\)]*', 'Pester (date'
                $jaCoCoReportXml = $jaCoCoReportXml -replace 'start="[0-9]*"', 'start=""'
                $jaCoCoReportXml = $jaCoCoReportXml -replace 'dump="[0-9]*"', 'dump=""'
                $jaCoCoReportXml = $jaCoCoReportXml -replace "$([System.Environment]::NewLine)", ''
                $jaCoCoReportXml = $jaCoCoReportXml -replace "$(Split-Path -Path $root -Leaf)", 'CommonRoot'
                $jaCoCoReportXml = $jaCoCoReportXml.Replace($root.Replace('\', '/'), '')
                (Clear-WhiteSpace $jaCoCoReportXml) | Should -Be (Clear-WhiteSpace '
                <?xml version="1.0" encoding="UTF-8" standalone="no"?>
                <!DOCTYPE report PUBLIC "-//JACOCO//DTD Report 1.1//EN" "report.dtd">
                <report name="Pester (date)">
                    <sessioninfo id="this" start="" dump="" />
                    <package name="CommonRoot">
                        <class name="CommonRoot/TestScript" sourcefilename="TestScript.ps1">
                            <method name="NestedFunction" desc="()" line="5">
                                <counter type="INSTRUCTION" missed="0" covered="2" />
                                <counter type="LINE" missed="0" covered="2" />
                                <counter type="METHOD" missed="0" covered="1" />
                            </method>
                            <method name="FunctionOne" desc="()" line="9">
                                <counter type="INSTRUCTION" missed="1" covered="6" />
                                <counter type="LINE" missed="0" covered="5" />
                                <counter type="METHOD" missed="0" covered="1" />
                            </method>
                            <method name="FunctionTwo" desc="()" line="22">
                                <counter type="INSTRUCTION" missed="1" covered="0" />
                                <counter type="LINE" missed="1" covered="0" />
                                <counter type="METHOD" missed="1" covered="0" />
                            </method>
                            <method name="&lt;script&gt;" desc="()" line="25">
                                <counter type="INSTRUCTION" missed="0" covered="3" />
                                <counter type="LINE" missed="0" covered="3" />
                                <counter type="METHOD" missed="0" covered="1" />
                            </method>
                            <method name="MyBaseClass" desc="()" line="31">
                                <counter type="INSTRUCTION" missed="0" covered="1" />
                                <counter type="LINE" missed="0" covered="1" />
                                <counter type="METHOD" missed="0" covered="1" />
                            </method>
                            <method name="MyClass" desc="()" line="39">
                                <counter type="INSTRUCTION" missed="0" covered="1" />
                                <counter type="LINE" missed="0" covered="1" />
                                <counter type="METHOD" missed="0" covered="1" />
                            </method>
                            <method name="MethodOne" desc="()" line="44">
                                <counter type="INSTRUCTION" missed="0" covered="1" />
                                <counter type="LINE" missed="0" covered="1" />
                                <counter type="METHOD" missed="0" covered="1" />
                            </method>
                            <method name="MethodTwo" desc="()" line="49">
                                <counter type="INSTRUCTION" missed="1" covered="0" />
                                <counter type="LINE" missed="1" covered="0" />
                                <counter type="METHOD" missed="1" covered="0" />
                            </method>
                            <counter type="INSTRUCTION" missed="3" covered="14" />
                            <counter type="LINE" missed="2" covered="13" />
                            <counter type="METHOD" missed="2" covered="6" />
                            <counter type="CLASS" missed="0" covered="1" />
                        </class>
                        <class name="CommonRoot/TestScript2" sourcefilename="TestScript2.ps1">
                            <method name="&lt;script&gt;" desc="()" line="1">
                                <counter type="INSTRUCTION" missed="0" covered="1" />
                                <counter type="LINE" missed="0" covered="1" />
                                <counter type="METHOD" missed="0" covered="1" />
                            </method>
                            <counter type="INSTRUCTION" missed="0" covered="1" />
                            <counter type="LINE" missed="0" covered="1" />
                            <counter type="METHOD" missed="0" covered="1" />
                            <counter type="CLASS" missed="0" covered="1" />
                        </class>
                        <sourcefile name="TestScript.ps1">
                            <line nr="5" mi="0" ci="1" mb="0" cb="0" />
                            <line nr="6" mi="0" ci="1" mb="0" cb="0" />
                            <line nr="9" mi="0" ci="1" mb="0" cb="0" />
                            <line nr="11" mi="0" ci="1" mb="0" cb="0" />
                            <line nr="12" mi="0" ci="1" mb="0" cb="0" />
                            <line nr="15" mi="1" ci="1" mb="0" cb="0" />
                            <line nr="17" mi="0" ci="2" mb="0" cb="0" />
                            <line nr="22" mi="1" ci="0" mb="0" cb="0" />
                            <line nr="25" mi="0" ci="1" mb="0" cb="0" />
                            <line nr="31" mi="0" ci="1" mb="0" cb="0" />
                            <line nr="39" mi="0" ci="1" mb="0" cb="0" />
                            <line nr="44" mi="0" ci="1" mb="0" cb="0" />
                            <line nr="49" mi="1" ci="0" mb="0" cb="0" />
                            <line nr="53" mi="0" ci="1" mb="0" cb="0" />
                            <line nr="54" mi="0" ci="1" mb="0" cb="0" />
                            <counter type="INSTRUCTION" missed="3" covered="14" />
                            <counter type="LINE" missed="2" covered="13" />
                            <counter type="METHOD" missed="2" covered="6" />
                            <counter type="CLASS" missed="0" covered="1" />
                        </sourcefile>
                        <sourcefile name="TestScript2.ps1">
                            <line nr="1" mi="0" ci="1" mb="0" cb="0" />
                            <counter type="INSTRUCTION" missed="0" covered="1" />
                            <counter type="LINE" missed="0" covered="1" />
                            <counter type="METHOD" missed="0" covered="1" />
                            <counter type="CLASS" missed="0" covered="1" />
                        </sourcefile>
                        <counter type="INSTRUCTION" missed="3" covered="15" />
                        <counter type="LINE" missed="2" covered="14" />
                        <counter type="METHOD" missed="2" covered="7" />
                        <counter type="CLASS" missed="0" covered="2" />
                    </package>
                    <package name="CommonRoot/TestSubFolder">
                        <class name="CommonRoot/TestSubFolder/TestScript3"
                            sourcefilename="TestSubFolder/TestScript3.ps1">
                            <method name="&lt;script&gt;" desc="()" line="1">
                                <counter type="INSTRUCTION" missed="0" covered="1" />
                                <counter type="LINE" missed="0" covered="1" />
                                <counter type="METHOD" missed="0" covered="1" />
                            </method>
                            <counter type="INSTRUCTION" missed="0" covered="1" />
                            <counter type="LINE" missed="0" covered="1" />
                            <counter type="METHOD" missed="0" covered="1" />
                            <counter type="CLASS" missed="0" covered="1" />
                        </class>
                        <sourcefile name="TestSubFolder/TestScript3.ps1">
                            <line nr="1" mi="0" ci="1" mb="0" cb="0" />
                            <counter type="INSTRUCTION" missed="0" covered="1" />
                            <counter type="LINE" missed="0" covered="1" />
                            <counter type="METHOD" missed="0" covered="1" />
                            <counter type="CLASS" missed="0" covered="1" />
                        </sourcefile>
                        <counter type="INSTRUCTION" missed="0" covered="1" />
                        <counter type="LINE" missed="0" covered="1" />
                        <counter type="METHOD" missed="0" covered="1" />
                        <counter type="CLASS" missed="0" covered="1" />
                    </package>
                    <counter type="INSTRUCTION" missed="3" covered="16" />
                    <counter type="LINE" missed="2" covered="15" />
                    <counter type="METHOD" missed="2" covered="8" />
                    <counter type="CLASS" missed="0" covered="3" />
                </report>
                ')
            }

            It 'JaCoCo for CoverageGutters report must be correct' {
                # when using output for CoverageGutters in VSCodethe output needs to be slightly different,
                # paths need to be reported relative to the output file and sourcefile name must be just the
                # file name, adding a new formatter, instead of changing the default one
                [String]$jaCoCoReportXml = Get-JaCoCoReportXml -CommandCoverage $breakpoints -TotalMilliseconds 10000 -CoverageReport $coverageReport -Format "CoverageGutters"
                $jaCoCoReportXml = $jaCoCoReportXml -replace 'Pester \([^\)]*', 'Pester (date'
                $jaCoCoReportXml = $jaCoCoReportXml -replace 'start="[0-9]*"', 'start=""'
                $jaCoCoReportXml = $jaCoCoReportXml -replace 'dump="[0-9]*"', 'dump=""'
                $jaCoCoReportXml = $jaCoCoReportXml -replace "$([System.Environment]::NewLine)", ''
                $jaCoCoReportXml = $jaCoCoReportXml -replace "$(Split-Path -Path $root -Leaf)", 'CommonRoot'
                $jaCoCoReportXml = $jaCoCoReportXml.Replace($root.Replace('\', '/'), '')
                (Clear-WhiteSpace $jaCoCoReportXml) | Should -Be (Clear-WhiteSpace '
                <?xml version="1.0" encoding="UTF-8" standalone="no"?>
                <!DOCTYPE report PUBLIC "-//JACOCO//DTD Report 1.1//EN" "report.dtd">
                <report name="Pester (date)">
                    <sessioninfo id="this" start="" dump="" />
                    <package name=".">
                        <class name="TestScript" sourcefilename="TestScript.ps1">
                            <method name="NestedFunction" desc="()" line="5">
                                <counter type="INSTRUCTION" missed="0" covered="2" />
                                <counter type="LINE" missed="0" covered="2" />
                                <counter type="METHOD" missed="0" covered="1" />
                            </method>
                            <method name="FunctionOne" desc="()" line="9">
                                <counter type="INSTRUCTION" missed="1" covered="6" />
                                <counter type="LINE" missed="0" covered="5" />
                                <counter type="METHOD" missed="0" covered="1" />
                            </method>
                            <method name="FunctionTwo" desc="()" line="22">
                                <counter type="INSTRUCTION" missed="1" covered="0" />
                                <counter type="LINE" missed="1" covered="0" />
                                <counter type="METHOD" missed="1" covered="0" />
                            </method>
                            <method name="&lt;script&gt;" desc="()" line="25">
                                <counter type="INSTRUCTION" missed="0" covered="3" />
                                <counter type="LINE" missed="0" covered="3" />
                                <counter type="METHOD" missed="0" covered="1" />
                            </method>
                            <method name="MyBaseClass" desc="()" line="31">
                                <counter type="INSTRUCTION" missed="0" covered="1" />
                                <counter type="LINE" missed="0" covered="1" />
                                <counter type="METHOD" missed="0" covered="1" />
                            </method>
                            <method name="MyClass" desc="()" line="39">
                                <counter type="INSTRUCTION" missed="0" covered="1" />
                                <counter type="LINE" missed="0" covered="1" />
                                <counter type="METHOD" missed="0" covered="1" />
                            </method>
                            <method name="MethodOne" desc="()" line="44">
                                <counter type="INSTRUCTION" missed="0" covered="1" />
                                <counter type="LINE" missed="0" covered="1" />
                                <counter type="METHOD" missed="0" covered="1" />
                            </method>
                            <method name="MethodTwo" desc="()" line="49">
                                <counter type="INSTRUCTION" missed="1" covered="0" />
                                <counter type="LINE" missed="1" covered="0" />
                                <counter type="METHOD" missed="1" covered="0" />
                            </method>
                            <counter type="INSTRUCTION" missed="3" covered="14" />
                            <counter type="LINE" missed="2" covered="13" />
                            <counter type="METHOD" missed="2" covered="6" />
                            <counter type="CLASS" missed="0" covered="1" />
                        </class>
                        <class name="TestScript2" sourcefilename="TestScript2.ps1">
                            <method name="&lt;script&gt;" desc="()" line="1">
                                <counter type="INSTRUCTION" missed="0" covered="1" />
                                <counter type="LINE" missed="0" covered="1" />
                                <counter type="METHOD" missed="0" covered="1" />
                            </method>
                            <counter type="INSTRUCTION" missed="0" covered="1" />
                            <counter type="LINE" missed="0" covered="1" />
                            <counter type="METHOD" missed="0" covered="1" />
                            <counter type="CLASS" missed="0" covered="1" />
                        </class>
                        <sourcefile name="TestScript.ps1">
                            <line nr="5" mi="0" ci="1" mb="0" cb="0" />
                            <line nr="6" mi="0" ci="1" mb="0" cb="0" />
                            <line nr="9" mi="0" ci="1" mb="0" cb="0" />
                            <line nr="11" mi="0" ci="1" mb="0" cb="0" />
                            <line nr="12" mi="0" ci="1" mb="0" cb="0" />
                            <line nr="15" mi="1" ci="1" mb="0" cb="0" />
                            <line nr="17" mi="0" ci="2" mb="0" cb="0" />
                            <line nr="22" mi="1" ci="0" mb="0" cb="0" />
                            <line nr="25" mi="0" ci="1" mb="0" cb="0" />
                            <line nr="31" mi="0" ci="1" mb="0" cb="0" />
                            <line nr="39" mi="0" ci="1" mb="0" cb="0" />
                            <line nr="44" mi="0" ci="1" mb="0" cb="0" />
                            <line nr="49" mi="1" ci="0" mb="0" cb="0" />
                            <line nr="53" mi="0" ci="1" mb="0" cb="0" />
                            <line nr="54" mi="0" ci="1" mb="0" cb="0" />
                            <counter type="INSTRUCTION" missed="3" covered="14" />
                            <counter type="LINE" missed="2" covered="13" />
                            <counter type="METHOD" missed="2" covered="6" />
                            <counter type="CLASS" missed="0" covered="1" />
                        </sourcefile>
                        <sourcefile name="TestScript2.ps1">
                            <line nr="1" mi="0" ci="1" mb="0" cb="0" />
                            <counter type="INSTRUCTION" missed="0" covered="1" />
                            <counter type="LINE" missed="0" covered="1" />
                            <counter type="METHOD" missed="0" covered="1" />
                            <counter type="CLASS" missed="0" covered="1" />
                        </sourcefile>
                        <counter type="INSTRUCTION" missed="3" covered="15" />
                        <counter type="LINE" missed="2" covered="14" />
                        <counter type="METHOD" missed="2" covered="7" />
                        <counter type="CLASS" missed="0" covered="2" />
                    </package>
                    <package name="TestSubFolder">
                        <class name="TestSubFolder/TestScript3" sourcefilename="TestScript3.ps1">
                            <method name="&lt;script&gt;" desc="()" line="1">
                                <counter type="INSTRUCTION" missed="0" covered="1" />
                                <counter type="LINE" missed="0" covered="1" />
                                <counter type="METHOD" missed="0" covered="1" />
                            </method>
                            <counter type="INSTRUCTION" missed="0" covered="1" />
                            <counter type="LINE" missed="0" covered="1" />
                            <counter type="METHOD" missed="0" covered="1" />
                            <counter type="CLASS" missed="0" covered="1" />
                        </class>
                        <sourcefile name="TestScript3.ps1">
                            <line nr="1" mi="0" ci="1" mb="0" cb="0" />
                            <counter type="INSTRUCTION" missed="0" covered="1" />
                            <counter type="LINE" missed="0" covered="1" />
                            <counter type="METHOD" missed="0" covered="1" />
                            <counter type="CLASS" missed="0" covered="1" />
                        </sourcefile>
                        <counter type="INSTRUCTION" missed="0" covered="1" />
                        <counter type="LINE" missed="0" covered="1" />
                        <counter type="METHOD" missed="0" covered="1" />
                        <counter type="CLASS" missed="0" covered="1" />
                    </package>
                    <counter type="INSTRUCTION" missed="3" covered="16" />
                    <counter type="LINE" missed="2" covered="15" />
                    <counter type="METHOD" missed="2" covered="8" />
                    <counter type="CLASS" missed="0" covered="3" />
                </report>
                ')
            }

            It 'Cobertura report must be correct' {
                [String]$coberturaReportXml = Get-CoberturaReportXml -TotalMilliseconds 10000 -CoverageReport $coverageReport
                $coberturaReportXml = $coberturaReportXml -replace 'timestamp="[0-9]*"', 'timestamp=""'
                $coberturaReportXml = $coberturaReportXml -replace "$([System.Environment]::NewLine)", ''
                $coberturaReportXml = $coberturaReportXml.Replace($root, 'CommonRoot')
                $coberturaReportXml = $coberturaReportXml.Replace($root.Replace('\', '/'), 'CommonRoot')
                (Clear-WhiteSpace $coberturaReportXml) | Should -Be (Clear-WhiteSpace '
                <?xml version="1.0" ?>
                <!DOCTYPE coverage SYSTEM "coverage-loose.dtd">
                <coverage lines-valid="17" lines-covered="15" line-rate="0.882352941176471" branches-valid="0"
                    branches-covered="0" branch-rate="1" timestamp="" version="0.1">
                    <sources>
                        <source>CommonRoot</source>
                    </sources>
                    <packages>
                        <package name="" line-rate="0.875" branch-rate="0">
                            <classes>
                                <class name="TestScript.ps1" filename="TestScript.ps1" line-rate="0.866666666666667"
                                    branch-rate="1">
                                    <methods>
                                        <method name="FunctionOne" signature="()">
                                            <lines>
                                                <line number="9" hits="1" />
                                                <line number="11" hits="1" />
                                                <line number="12" hits="1" />
                                                <line number="15" hits="1" />
                                                <line number="17" hits="2" />
                                            </lines>
                                        </method>
                                        <method name="FunctionTwo" signature="()">
                                            <lines>
                                                <line number="22" hits="0" />
                                            </lines>
                                        </method>
                                        <method name="MethodOne" signature="()">
                                            <lines>
                                                <line number="44" hits="1" />
                                            </lines>
                                        </method>
                                        <method name="MethodTwo" signature="()">
                                            <lines>
                                                <line number="49" hits="0" />
                                            </lines>
                                        </method>
                                        <method name="MyBaseClass" signature="()">
                                            <lines>
                                                <line number="31" hits="1" />
                                            </lines>
                                        </method>
                                        <method name="MyClass" signature="()">
                                            <lines>
                                                <line number="39" hits="1" />
                                            </lines>
                                        </method>
                                        <method name="NestedFunction" signature="()">
                                            <lines>
                                                <line number="5" hits="1" />
                                                <line number="6" hits="1" />
                                            </lines>
                                        </method>
                                    </methods>
                                    <lines>
                                        <line number="5" hits="1" />
                                        <line number="6" hits="1" />
                                        <line number="9" hits="1" />
                                        <line number="11" hits="1" />
                                        <line number="12" hits="1" />
                                        <line number="15" hits="1" />
                                        <line number="17" hits="2" />
                                        <line number="22" hits="0" />
                                        <line number="25" hits="1" />
                                        <line number="31" hits="1" />
                                        <line number="39" hits="1" />
                                        <line number="44" hits="1" />
                                        <line number="49" hits="0" />
                                        <line number="53" hits="1" />
                                        <line number="54" hits="1" />
                                    </lines>
                                </class>
                                <class name="TestScript2.ps1" filename="TestScript2.ps1" line-rate="1"
                                    branch-rate="1">
                                    <methods />
                                    <lines>
                                        <line number="1" hits="1" />
                                    </lines>
                                </class>
                            </classes>
                        </package>
                        <package name="TestSubFolder" line-rate="1" branch-rate="0">
                            <classes>
                                <class name="TestScript3.ps1" filename="TestSubFolder/TestScript3.ps1" line-rate="1"
                                    branch-rate="1">
                                    <methods />
                                    <lines>
                                        <line number="1" hits="1" />
                                    </lines>
                                </class>
                            </classes>
                        </package>
                    </packages>
                </coverage>
                ')
            }

            It 'JaCoCo returns empty string when there are 0 analyzed commands' {
                $coverageReport = [PSCustomObject] @{ NumberOfCommandsAnalyzed = 0 }
                [String]$jaCoCoReportXml = Get-JaCoCoReportXml -CommandCoverage @{} -TotalMilliseconds 10000 -CoverageReport $coverageReport -Format "CoverageGutters"
                $jaCoCoReportXml | Should -Not -Be $null
                $jaCoCoReportXml | Should -Be ([String]::Empty)
            }

            It 'Cobertura returns empty string when there are 0 analyzed commands' {
                $coverageReport = [PSCustomObject] @{ NumberOfCommandsAnalyzed = 0 }
                [String]$coberturaReportXml = Get-CoberturaReportXml -CoverageReport $coverageReport -TotalMilliseconds 10000
                $coberturaReportXml | Should -Not -Be $null
                $coberturaReportXml | Should -Be ([String]::Empty)
            }

            It 'Reports the right line numbers' {
                $coverageReport.HitCommands[$coverageReport.NumberOfCommandsExecuted - 1].Line | Should -Be 1
                $coverageReport.HitCommands[$coverageReport.NumberOfCommandsExecuted - 1].StartLine | Should -Be 1
                $coverageReport.HitCommands[$coverageReport.NumberOfCommandsExecuted - 1].EndLine | Should -Be 3
            }

            It 'Reports the right column numbers' {
                $coverageReport.HitCommands[$coverageReport.NumberOfCommandsExecuted - 1].StartColumn | Should -Be 13
                $coverageReport.HitCommands[$coverageReport.NumberOfCommandsExecuted - 1].EndColumn | Should -Be 24
            }

            AfterAll {
                if ($UseBreakpoints) {
                    Exit-CoverageAnalysis -CommandCoverage $breakpoints
                }
            }
        }

        Context 'Single function with missed commands using <description>' -Foreach @(
            @{ UseBreakpoints = $true; Description = "breakpoints" }
            @{ UseBreakpoints = $false; Description = "Profiler based cc" }
        ) {
            BeforeAll {
                $breakpoints = Enter-CoverageAnalysis -CodeCoverage @{Path = $testScriptPath; Function = 'FunctionTwo' } -UseBreakpoints $UseBreakpoints
                @($breakpoints).Count | Should -Be 1 -Because "it has the proper number of breakpoints defined"

                if ($UseBreakpoints) {
                    & $testScriptPath
                }
                else {
                    $patched, $tracer = Start-TraceScript $breakpoints
                    try { & $testScriptPath } finally { Stop-TraceScript -Patched $patched }
                    $measure = $tracer.Hits
                }

                $coverageReport = Get-CoverageReport -CommandCoverage $breakpoints -Measure $measure
            }

            It 'Reports the proper number of executed commands' {
                $coverageReport.NumberOfCommandsExecuted | Should -Be 0
            }

            It 'Reports the proper number of analyzed commands' {
                $coverageReport.NumberOfCommandsAnalyzed | Should -Be 1
            }

            It 'Reports the proper number of missed commands' {
                $coverageReport.MissedCommands.Count | Should -Be 1
            }

            It 'Reports the correct missed command' {
                $coverageReport.MissedCommands[0].Command | Should -Be "'I am function two.  I never get called.'"
            }

            It 'Reports the proper number of hit commands' {
                $coverageReport.HitCommands.Count | Should -Be 0
            }

            AfterAll {
                if ($UseBreakpoints) {
                    Exit-CoverageAnalysis -CommandCoverage $breakpoints
                }
            }
        }

        Context 'Single function with no missed commands using <description>' -Foreach @(
            @{ UseBreakpoints = $true; Description = "breakpoints" }
            @{ UseBreakpoints = $false; Description = "Profiler based cc" }
        ) {
            BeforeAll {

                $breakpoints = Enter-CoverageAnalysis -CodeCoverage @{Path = $testScriptPath; Function = 'FunctionOne' } -UseBreakpoints $UseBreakpoints

                @($breakpoints).Count | Should -Be 9 -Because "it has the proper number of breakpoints defined"

                if ($UseBreakpoints) {
                    & $testScriptPath
                }
                else {
                    $patched, $tracer = Start-TraceScript $breakpoints
                    try { & $testScriptPath } finally { Stop-TraceScript -Patched $patched }
                    $measure = $tracer.Hits
                }

                $coverageReport = Get-CoverageReport -CommandCoverage $breakpoints -Measure $measure
            }

            It 'Reports the proper number of executed commands' {
                $coverageReport.NumberOfCommandsExecuted | Should -Be 8
            }

            It 'Reports the proper number of analyzed commands' {
                $coverageReport.NumberOfCommandsAnalyzed | Should -Be 9
            }

            It 'Reports the proper number of missed commands' {
                $coverageReport.MissedCommands.Count | Should -Be 1
            }

            It 'Reports the proper number of hit commands' {
                $coverageReport.HitCommands.Count | Should -Be 8
            }

            It 'Reports the correct hit command' {
                $coverageReport.HitCommands[0].Command | Should -Be "'I am the nested function.'"
            }

            AfterAll {
                if ($UseBreakpoints) {
                    Exit-CoverageAnalysis -CommandCoverage $breakpoints
                }
            }
        }

        Context 'Range of lines using <description>' -Foreach @(
            @{ UseBreakpoints = $true; Description = "breakpoints" }
            @{ UseBreakpoints = $false; Description = "Profiler based cc" }
        ) {
            BeforeAll {

                $breakpoints = Enter-CoverageAnalysis -CodeCoverage @{Path = $testScriptPath; StartLine = 11; EndLine = 12 } -UseBreakpoints $UseBreakpoints

                @($breakpoints).Count | Should -Be 2 -Because 'it has the proper number of breakpoints defined'

                if ($UseBreakpoints) {
                    & $testScriptPath
                }
                else {
                    $patched, $tracer = Start-TraceScript $breakpoints
                    try { & $testScriptPath } finally { Stop-TraceScript -Patched $patched }
                    $measure = $tracer.Hits
                }

                $coverageReport = Get-CoverageReport -CommandCoverage $breakpoints -Measure $measure
            }

            It 'Reports the proper number of executed commands' {
                $coverageReport.NumberOfCommandsExecuted | Should -Be 2
            }

            It 'Reports the proper number of analyzed commands' {
                $coverageReport.NumberOfCommandsAnalyzed | Should -Be 2
            }

            It 'Reports the proper number of missed commands' {
                $coverageReport.MissedCommands.Count | Should -Be 0
            }

            It 'Reports the proper number of hit commands' {
                $coverageReport.HitCommands.Count | Should -Be 2
            }

            It 'Reports the correct hit command' {
                $coverageReport.HitCommands[0].Command | Should -Be "'I am functionOne'"
            }

            AfterAll {
                if ($UseBreakpoints) {
                    Exit-CoverageAnalysis -CommandCoverage $breakpoints
                }
            }
        }

        Context 'Function wildcard resolution using <description>' -Foreach @(
            @{ UseBreakpoints = $true; Description = "breakpoints" }
            @{ UseBreakpoints = $false; Description = "Profiler based cc" }
        ) {
            BeforeAll {
                $breakpoints = Enter-CoverageAnalysis -CodeCoverage @{Path = "$(Join-Path -Path $root -ChildPath *.ps1)"; Function = '*' } -UseBreakpoints $UseBreakpoints

                @($breakpoints).Count | Should -Be 14 -Because 'it has the proper number of breakpoints defined'

                if ($UseBreakpoints) {
                    & $testScriptPath
                }
                else {
                    $patched, $tracer = Start-TraceScript $breakpoints
                    try { & $testScriptPath } finally { Stop-TraceScript -Patched $patched }
                    $measure = $tracer.Hits
                }

                $coverageReport = Get-CoverageReport -CommandCoverage $breakpoints -Measure $measure
            }

            It 'Reports the proper number of executed commands' {
                $coverageReport.NumberOfCommandsExecuted | Should -Be 11
            }

            It 'Reports the proper number of analyzed commands' {
                $coverageReport.NumberOfCommandsAnalyzed | Should -Be 14
            }

            It 'Reports the proper number of analyzed files' {
                $coverageReport.NumberOfFilesAnalyzed | Should -Be 1
            }

            It 'Reports the proper number of missed commands' {
                $coverageReport.MissedCommands.Count | Should -Be 3
            }

            It 'Reports the correct missed command' {
                $coverageReport.MissedCommands[0].Command | Should -Be "'I cannot get called.'"
                $coverageReport.MissedCommands[1].Command | Should -Be "'I am function two.  I never get called.'"
            }

            It 'Reports the proper number of hit commands' {
                $coverageReport.HitCommands.Count | Should -Be 11
            }

            It 'Reports the correct hit command' {
                $coverageReport.HitCommands[0].Command | Should -Be "'I am the nested function.'"
            }

            AfterAll {
                if ($UseBreakpoints) {
                    Exit-CoverageAnalysis -CommandCoverage $breakpoints
                }
            }
        }

        # Classes have been introduced in PowerShell 5.0
        if ($PSVersionTable.PSVersion.Major -ge 5) {
            Context 'Single class using <description>' -Foreach @(
                @{ UseBreakpoints = $true; Description = "breakpoints" }
                @{ UseBreakpoints = $false; Description = "Profiler based cc" }
            ) {
                BeforeAll {

                    $breakpoints = Enter-CoverageAnalysis -CodeCoverage @{Path = $testScriptPath; Class = 'MyClass' } -UseBreakpoints $UseBreakpoints

                    @($breakpoints).Count | Should -Be 3 -Because 'it has the proper number of breakpoints defined'

                    if ($UseBreakpoints) {
                        & $testScriptPath
                    }
                    else {
                        $patched, $tracer = Start-TraceScript $breakpoints
                        try { & $testScriptPath } finally { Stop-TraceScript -Patched $patched }
                        $measure = $tracer.Hits
                    }

                    $coverageReport = Get-CoverageReport -CommandCoverage $breakpoints -Measure $measure
                }

                It 'Reports the proper number of executed commands' {
                    $coverageReport.NumberOfCommandsExecuted | Should -Be 2
                }

                It 'Reports the proper number of analyzed commands' {
                    $coverageReport.NumberOfCommandsAnalyzed | Should -Be 3
                }

                It 'Reports the proper number of missed commands' {
                    $coverageReport.MissedCommands.Count | Should -Be 1
                }

                It 'Reports the proper number of hit commands' {
                    $coverageReport.HitCommands.Count | Should -Be 2
                }

                AfterAll {
                    if ($UseBreakpoints) {
                        Exit-CoverageAnalysis -CommandCoverage $breakpoints
                    }
                }
            }

            Context 'Class wildcard resolution using <description>' -Foreach @(
                @{ UseBreakpoints = $true; Description = "breakpoints" }
                @{ UseBreakpoints = $false; Description = "Profiler based cc" }
            ) {
                BeforeAll {

                    $breakpoints = Enter-CoverageAnalysis -CodeCoverage @{Path = $testScriptPath; Class = '*' } -UseBreakpoints $UseBreakpoints

                    @($breakpoints).Count | Should -Be 4 -Because 'it has the proper number of breakpoints defined'

                    if ($UseBreakpoints) {
                        & $testScriptPath
                    }
                    else {
                        $patched, $tracer = Start-TraceScript $breakpoints
                        try { & $testScriptPath } finally { Stop-TraceScript -Patched $patched }
                        $measure = $tracer.Hits
                    }

                    $coverageReport = Get-CoverageReport -CommandCoverage $breakpoints -Measure $measure
                }

                It 'Reports the proper number of executed commands' {
                    $coverageReport.NumberOfCommandsExecuted | Should -Be 3
                }

                It 'Reports the proper number of analyzed commands' {
                    $coverageReport.NumberOfCommandsAnalyzed | Should -Be 4
                }

                It 'Reports the proper number of missed commands' {
                    $coverageReport.MissedCommands.Count | Should -Be 1
                }

                It 'Reports the proper number of hit commands' {
                    $coverageReport.HitCommands.Count | Should -Be 3
                }

                AfterAll {
                    if ($UseBreakpoints) {
                        Exit-CoverageAnalysis -CommandCoverage $breakpoints
                    }
                }
            }

            Context 'Class and function filter using <description>' -Foreach @(
                @{ UseBreakpoints = $true; Description = "breakpoints" }
                @{ UseBreakpoints = $false; Description = "Profiler based cc" }
            ) {
                BeforeAll {

                    $breakpoints = Enter-CoverageAnalysis -CodeCoverage @{Path = $testScriptPath; Class = 'MyClass'; Function = 'MethodTwo' } -UseBreakpoints $UseBreakpoints

                    @($breakpoints).Count | Should -Be 1 -Because 'it has the proper number of breakpoints defined'

                    if ($UseBreakpoints) {
                        & $testScriptPath
                    }
                    else {
                        $patched, $tracer = Start-TraceScript $breakpoints
                        try { & $testScriptPath } finally { Stop-TraceScript -Patched $patched }
                        $measure = $tracer.Hits
                    }

                    $coverageReport = Get-CoverageReport -CommandCoverage $breakpoints -Measure $measure
                }

                It 'Reports the proper number of executed commands' {
                    $coverageReport.NumberOfCommandsExecuted | Should -Be 0
                }

                It 'Reports the proper number of analyzed commands' {
                    $coverageReport.NumberOfCommandsAnalyzed | Should -Be 1
                }

                It 'Reports the proper number of missed commands' {
                    $coverageReport.MissedCommands.Count | Should -Be 1
                }

                It 'Reports the proper number of hit commands' {
                    $coverageReport.HitCommands.Count | Should -Be 0
                }

                AfterAll {
                    if ($UseBreakpoints) {
                        Exit-CoverageAnalysis -CommandCoverage $breakpoints
                    }
                }
            }
        }
        else {
            Context 'Single class when not supported using <description>' -Foreach @(
                @{ UseBreakpoints = $true; Description = "breakpoints" }
                @{ UseBreakpoints = $false; Description = "Profiler based cc" }
            ) {
                BeforeAll {

                    $breakpoints = Enter-CoverageAnalysis -CodeCoverage @{ Path = $testScriptPath; Class = 'MyClass' } -UseBreakpoints $UseBreakpoints

                    @($breakpoints).Count | Should -Be 0 -Because 'it has the proper number of breakpoints defined'

                    if ($UseBreakpoints) {
                        & $testScriptPath
                    }
                    else {
                        $patched, $tracer = Start-TraceScript $breakpoints
                        try { & $testScriptPath } finally { Stop-TraceScript -Patched $patched }
                        $measure = $tracer.Hits
                    }

                    $coverageReport = Get-CoverageReport -CommandCoverage $breakpoints -Measure $measure
                }

                It 'Reports the proper number of executed commands' {
                    $coverageReport.NumberOfCommandsExecuted | Should -Be 0
                }

                It 'Reports the proper number of analyzed commands' {
                    $coverageReport.NumberOfCommandsAnalyzed | Should -Be 0
                }

                It 'Reports the proper number of missed commands' {
                    $coverageReport.MissedCommands.Count | Should -Be 0
                }

                It 'Reports the proper number of hit commands' {
                    $coverageReport.HitCommands.Count | Should -Be 0
                }

                AfterAll {
                    if ($UseBreakpoints) {
                        Exit-CoverageAnalysis -CommandCoverage $breakpoints
                    }
                }
            }
        }
    }

    Describe 'Path resolution for test files' {
        BeforeAll {
            $root = (Get-PSDrive TestDrive).Root
            $rootSubFolder = Join-Path -Path $root -ChildPath TestSubFolder

            $null = New-Item -Path $rootSubFolder -ItemType Directory -ErrorAction SilentlyContinue
            $null = New-Item -Path $(Join-Path -Path $root -ChildPath TestScript.psm1) -ItemType File -ErrorAction SilentlyContinue
            $null = New-Item -Path $(Join-Path -Path $root -ChildPath TestScript.ps1) -ItemType File -ErrorAction SilentlyContinue
            $null = New-Item -Path $(Join-Path -Path $root -ChildPath TestScript.tests.ps1) -ItemType File -ErrorAction SilentlyContinue
            $null = New-Item -Path $(Join-Path -Path $root -ChildPath TestScript2.tests.ps1) -ItemType File -ErrorAction SilentlyContinue
            $null = New-Item -Path $(Join-Path -Path $rootSubFolder -ChildPath TestScript3.ps1) -Force -ItemType File -ErrorAction SilentlyContinue
            $null = New-Item -Path $(Join-Path -Path $rootSubFolder -ChildPath TestScript3.tests.ps1) -Force -ItemType File -ErrorAction SilentlyContinue
        }
        Context 'Using Path-input (auto-detect)' {
            It 'Includes script files by default when using wildcard path' {
                $coverageInfo = Get-CoverageInfoFromUserInput "$(Join-Path -Path $root -ChildPath *)"
                $PesterTests = @($coverageInfo |
                        Select-Object -ExpandProperty Path |
                        Where-Object { $_ -notmatch '\.tests.ps1$' })
                $PesterTests.Count | Should -Be 3
                $PesterTests | Should -Contain $(Join-Path -Path $root -ChildPath TestScript.psm1)
                $PesterTests | Should -Contain $(Join-Path -Path $root -ChildPath TestScript.ps1)
                $PesterTests | Should -Contain $(Join-Path -Path $rootSubFolder -ChildPath TestScript3.ps1)
            }
            It 'Excludes test files by default when using wildcard path' {
                $coverageInfo = Get-CoverageInfoFromUserInput "$(Join-Path -Path $root -ChildPath *)"
                $PesterTests = @($coverageInfo |
                        Select-Object -ExpandProperty Path |
                        Where-Object { $_ -match '\.tests.ps1$' })
                $PesterTests | Should -BeNullOrEmpty
            }
            It 'Includes test files when specified in wildcard path' {
                $coverageInfo = Get-CoverageInfoFromUserInput "$(Join-Path -Path $root -ChildPath *.tests.ps1)"
                $PesterTests = @($coverageInfo |
                        Select-Object -ExpandProperty Path |
                        Where-Object { $_ -match '\.tests.ps1$' })
                $PesterTests.Count | Should -Be 2
                $PesterTests | Should -Contain $(Join-Path -Path $root -ChildPath TestScript.tests.ps1)
                $PesterTests | Should -Contain $(Join-Path -Path $root -ChildPath TestScript2.tests.ps1)
            }
            It 'Includes test file when targeted directly using filepath' {
                $path = Join-Path -Path $root -ChildPath TestScript.tests.ps1
                $coverageInfo = Get-CoverageInfoFromUserInput $path
                $PesterTests = $coverageInfo | Select-Object -ExpandProperty Path
                $PesterTests | Should -Be $path
            }
        }
        Context 'Using object-input' {
            It 'Excludes test files when IncludeTests is not specified' {
                $coverageInfo = Get-CoverageInfoFromUserInput @{ Path = "$(Join-Path -Path $root -ChildPath TestScript.tests.ps1)" }
                $PesterTests = $coverageInfo | Select-Object -ExpandProperty Path
                $PesterTests | Should -BeNullOrEmpty
            }
            It 'Excludes test files when IncludeTests is false' {
                $coverageInfo = Get-CoverageInfoFromUserInput @{ Path = "$(Join-Path -Path $root -ChildPath TestScript.tests.ps1)"; IncludeTests = $false }
                $PesterTests = $coverageInfo | Select-Object -ExpandProperty Path
                $PesterTests | Should -BeNullOrEmpty
            }
            It 'Includes test files when IncludeTests is true' {
                $path = Join-Path -Path $root -ChildPath TestScript.tests.ps1
                $coverageInfo = Get-CoverageInfoFromUserInput @{ Path = $path; IncludeTests = $true }
                $PesterTests = $coverageInfo | Select-Object -ExpandProperty Path
                $PesterTests | Should -Be $path
            }
            It 'Includes test files when IncludeTests is true and using wildcard path' {
                $coverageInfo = Get-CoverageInfoFromUserInput @{ Path = "$(Join-Path -Path $root -ChildPath *)"; IncludeTests = $true }
                $PesterTests = $coverageInfo | Select-Object -ExpandProperty Path
                $PesterTests.Count | Should -Be 6
                $PesterTests | Should -Contain $(Join-Path -Path $root -ChildPath TestScript.psm1)
                $PesterTests | Should -Contain $(Join-Path -Path $root -ChildPath TestScript.ps1)
                $PesterTests | Should -Contain $(Join-Path -Path $root -ChildPath TestScript.tests.ps1)
                $PesterTests | Should -Contain $(Join-Path -Path $root -ChildPath TestScript2.tests.ps1)
                $PesterTests | Should -Contain $(Join-Path -Path $rootSubFolder -ChildPath TestScript3.ps1)
                $PesterTests | Should -Contain $(Join-Path -Path $rootSubFolder -ChildPath TestScript3.tests.ps1)
            }
        }
    }

    #     Describe 'Stripping common parent paths' {

    #         If ( (& $SafeCommands['Get-Variable'] -Name IsLinux -Scope Global -ErrorAction SilentlyContinue) -or
    #             (& $SafeCommands['Get-Variable'] -Name IsMacOS -Scope Global -ErrorAction SilentlyContinue)) {

    #             $paths = @(
    #                 Normalize-Path '/usr/lib/Common\Folder\UniqueSubfolder1/File.ps1'
    #                 Normalize-Path '/usr/lib/Common\Folder\UniqueSubfolder2/File2.ps1'
    #                 Normalize-Path '/usr/lib/Common\Folder\UniqueSubfolder3/File3.ps1'

    #                 $expectedCommonPath = Normalize-Path '/usr/lib/Common/Folder'

    #             )

    #         }
    #         Else {

    #             $paths = @(
    #                 Normalize-Path 'C:\Common\Folder\UniqueSubfolder1/File.ps1'
    #                 Normalize-Path 'C:\Common\Folder\UniqueSubfolder2/File2.ps1'
    #                 Normalize-Path 'C:\Common\Folder\UniqueSubfolder3/File3.ps1'

    #                 $expectedCommonPath = Normalize-Path 'C:\Common/Folder'

    #             )

    #         }

    #         $commonPath = Get-CommonParentPath -Path $paths


    #         It 'Identifies the correct parent path' {
    #             $commonPath | Should -Be $expectedCommonPath
    #         }

    #         $expectedRelativePath = Normalize-Path 'UniqueSubfolder1/File.ps1'
    #         $relativePath = Get-RelativePath -Path $paths[0] -RelativeTo $commonPath

    #         It 'Strips the common path correctly' {
    #             $relativePath | Should -Be $expectedRelativePath
    #         }
    #     }

    #     #Workaround for Linux and MacOS - they don't have DSC by default installed with PowerShell - disable tests on these platforms
    #     if ((Get-Module -ListAvailable PSDesiredStateConfiguration) -and $PSVersionTable.PSVersion.Major -ge 4 -and ((GetPesterOS) -eq 'Windows')) {

    #         Describe 'Analyzing coverage of a DSC configuration' {
    #             BeforeAll {
    #                 $root = (Get-PSDrive TestDrive).Root

    #                 $null = New-Item -Path $root\TestScriptWithConfiguration.ps1 -ItemType File -ErrorAction SilentlyContinue

    #                 Set-Content -Path $root\TestScriptWithConfiguration.ps1 -Value @'
    #                     $line1 = $true   # Triggers breakpoint
    #                     $line2 = $true   # Triggers breakpoint

    #                     configuration MyTestConfig   # does NOT trigger breakpoint
    #                     {
    #                         Import-DscResource -ModuleName PSDesiredStateConfiguration # Triggers breakpoint in PowerShell v5 but not in v4

    #                         Node localhost    # Triggers breakpoint
    #                         {
    #                             WindowsFeature XPSViewer   # Triggers breakpoint
    #                             {
    #                                 Name = 'XPS-Viewer'  # does NOT trigger breakpoint
    #                                 Ensure = 'Present'   # does NOT trigger breakpoint
    #                             }
    #                         }

    #                         return # does NOT trigger breakpoint

    #                         $doesNotExecute = $true   # Triggers breakpoint
    #                     }

    #                     $line3 = $true   # Triggers breakpoint

    #                     return   # does NOT trigger breakpoint

    #                     $doesnotexecute = $true   # Triggers breakpoint
    # '@

    #                 Enter-CoverageAnalysis -CodeCoverage "$root\TestScriptWithConfiguration.ps1" -PesterState $testState

    #                 #the AST does not parse Import-DscResource -ModuleName PSDesiredStateConfiguration on PowerShell 4
    #                 $runsInPowerShell4 = $PSVersionTable.PSVersion.Major -eq 4

    #                 if ($runsInPowerShell4) {
    #                     $expected = 7
    #                 }
    #                 else {
    #                     $expected = 8
    #                 }

    #                 @($breakpoints).Count | Should -Be $expected -Because 'it has the proper number of breakpoints defined'

    #                 $null = . "$root\TestScriptWithConfiguration.ps1"

    #                 $coverageReport = Get-CoverageReport -CommandCoverage $breakpoints
    #             }

    #             It 'Reports the proper number of missed commands before running the configuration' {
    #                 if ($runsInPowerShell4) {
    #                     $expected = 4
    #                 }
    #                 else {
    #                     $expected = 5
    #                 }

    #                 $coverageReport.MissedCommands.Count | Should -Be $expected
    #             }
    #             It 'Reports the proper number of missed commands after running the configuration' {

    #                 MyTestConfig -OutputPath $root

    #                 $coverageReport = Get-CoverageReport -CommandCoverage $breakpoints

    #                 if ($runsInPowerShell4) {
    #                     $expected = 2
    #                 }
    #                 else {
    #                     $expected = 3
    #                 }

    #                 $coverageReport.MissedCommands.Count | Should -Be $expected
    #             }

    #             AfterAll {
    #                 Exit-CoverageAnalysis -CommandCoverage $breakpoints
    #             }
    #         }
    #     }
}
