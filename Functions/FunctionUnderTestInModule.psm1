function FunctionUnderTestInModule {
    return InternalModuleFunction
}


function Global:InternalModuleFunction {
	return "I am the real module function"
}

if($TestContext) {
	Export-ModuleMember -Function *
} else {
	Export-ModuleMember -Function FunctionUnderTestInModule
}