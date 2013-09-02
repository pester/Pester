function FunctionUnderTestInModule {
    return InternalModuleFunction
}

function FunctionUnderTestInModuleCallsFunctionWithParams {
	param(
		[String]$Param1
	)
    return InternalModuleFunctionWithParams $Param1
}

function Global:InternalModuleFunctionWithParams {
	param(
		[String]$Param1
	)
    return "I am the real module function with params: {0}" -f $Param1
}

function Global:InternalModuleFunction {
	return "I am the real module function"
}

Export-ModuleMember -Function *