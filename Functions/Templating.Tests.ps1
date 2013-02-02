Describe "Replacing strings" {
    It "should remove powershell backtick when replacing strings" {
        $replacments = Get-ReplacementArgs "@@test@@" @{ test = "This is a test don``t do this" }
        $replacments | Should Be "-replace '@@test@@', 'This is a test dont do this'"

    }

    It "should remove single quote when replacing strings" {
        $replacments = Get-ReplacementArgs "@@test@@" @{ test = "This is a test don't do this" }
        $replacments | Should Be "-replace '@@test@@', 'This is a test dont do this'"
    }
}

Describe "Templating" {
    it "Should get a template from the template folder" {
        $template = Get-Template "TestCaseSuccess.template.xml"
        $template | Should Match 'test-case name="@@name@@"'
    }
    it "Should replace strings in template with the according value" {     
        $template = Invoke-Template "TestCaseSuccess.template.xml" @{ name = "Template Test" }
        $template | Should Match 'test-case name="Template Test"'
    }
}
