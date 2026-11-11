
Describe 'All The Tests' {
	Context 'Reasons' {
		It 'Skips...' {
			Set-ItResult -Skipped -Because 'I am skipped'
		}
		It 'Does not skip' {
			$true | Should -BeTrue
		}
		It 'is Inconclusive' {
			Set-ItResult -Inconclusive -Because 'I am inconclusive!'
		}
		It 'is Failed!' {
			$true | Should -BeFalse -Because 'I am failed test'
		}
	}

	Context 'No Reasons' {
		It 'Skips...' {
			Set-ItResult -Skipped
		}
		It 'Does not skip' {
			$true | Should -BeTrue
		}
		It 'is Inconclusive' {
			Set-ItResult -Inconclusive
		}
		It 'is Failed!' {
			$true | Should -BeFalse
		}
	}

	Context 'It Reasons' {
		It 'Skips' -Skip -Reason 'I am Skipped' {
			$true | Should -BeTrue
		}
	}

	Context 'It No Reasons' {
		It 'Skips' -Skip {
			$true | Should -BeTrue
		}
	}

	Context 'Context Reasons' -Skip -Reason 'I am Skipped' {
		It 'Skips' {
			$true | Should -BeTrue
		}
	}

	Context 'Context No Reasons' -Skip {
		It 'Skips' {
			$true | Should -BeTrue
		}
	}

	Describe 'Describe Reasons' -Skip -Reason 'I am Skipped' {
		It 'Skips' {
			$true | Should -BeTrue
		}
	}

	Describe 'Describe No Reasons' -Skip {
		It 'Skips' {
			$true | Should -BeTrue
		}
	}
}
