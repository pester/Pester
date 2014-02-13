$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\$sut"

Describe "BeExactly" {
    It "passes if letter case matches" {
		'a' | Should BeExactly 'a'
    }
	It "fails if letter case doesn't match" {
		'A' | Should Not BeExactly 'a'
    }
	It "passes for numbers" {
		1 | Should BeExactly 1
		2.15 | Should BeExactly 2.15
	}
}