###
# ==++==
#
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
###

<#
	Overrides the default Write-Debug so that the output gets routed back thru the
	$request.Debug() function
#>
function Write-Debug {
	param(
	[Parameter(Mandatory=$true)][string] $message,
	[parameter(ValueFromRemainingArguments=$true)]
	[object[]]
	 $args= @()
	)

	if( -not $request  ) {
		if( -not $args  ) {
			Microsoft.PowerShell.Utility\write-verbose $message
			return
		}

		$msg = [system.string]::format($message, $args)
		Microsoft.PowerShell.Utility\write-verbose $msg
		return
	}

	if( -not $args  ) {
		$request.Debug($message);
		return
	}
	$request.Debug($message,$args);
}

<#
	Overrides the default Write-Verbose so that the output gets routed back thru the
	$request.Verbose() function
#>

function Write-Verbose{
	param(
	[Parameter(Mandatory=$true)][string] $message,
	[parameter(ValueFromRemainingArguments=$true)]
	[object[]]
	 $args= @()
	)

	if( -not $request ) {
		if( -not $args ) {
			Microsoft.PowerShell.Utility\write-verbose $message
			return
		}

		$msg = [system.string]::format($message, $args)
		Microsoft.PowerShell.Utility\write-verbose $msg
		return
	}

	if( -not $args ) {
		$request.Verbose($message);
		return
	}
	$request.Verbose($message,$args);
}

<#
	Overrides the default Write-Warning so that the output gets routed back thru the
	$request.Warning() function
#>

function Write-Warning{
	param(
	[Parameter(Mandatory=$true)][string] $message,
	[parameter(ValueFromRemainingArguments=$true)]
	[object[]]
	 $args= @()
	)

	if( -not $request ) {
		if( -not $args ) {
			Microsoft.PowerShell.Utility\write-warning $message
			return
		}

		$msg = [system.string]::format($message, $args)
		Microsoft.PowerShell.Utility\write-warning $msg
		return
	}

	if( -not $args ) {
		$request.Warning($message);
		return
	}
	$request.Warning($message,$args);
}

<#
	Creates a new instance of a PackageSource object
#>
function New-PackageSource {
	param(
		[Parameter(Mandatory=$true)][string] $name,
		[Parameter(Mandatory=$true)][string] $location,
		[Parameter(Mandatory=$true)][bool] $trusted,
		[Parameter(Mandatory=$true)][bool] $registered,
		[bool] $valid = $false,
		[System.Collections.Hashtable] $details = $null
	)

	return New-Object -TypeName Microsoft.OneGet.MetaProvider.PowerShell.PackageSource -ArgumentList $name,$location,$trusted,$registered,$valid,$details
}

<#
	Creates a new instance of a SoftwareIdentity object
#>
function New-SoftwareIdentity {
	param(
		[Parameter(Mandatory=$true)][string] $fastPackageReference,
		[Parameter(Mandatory=$true)][string] $name,
		[Parameter(Mandatory=$true)][string] $version,
		[Parameter(Mandatory=$true)][string] $versionScheme,
		[Parameter(Mandatory=$true)][string] $source,
		[string] $summary,
		[string] $searchKey = $null,
		[string] $fullPath = $null,
		[string] $filename = $null,
		[System.Collections.Hashtable] $details = $null,
		[System.Collections.ArrayList] $entities = $null,
		[System.Collections.ArrayList] $links = $null,
		[bool] $fromTrustedSource = $false
	)
	return New-Object -TypeName Microsoft.OneGet.MetaProvider.PowerShell.SoftwareIdentity -ArgumentList $fastPackageReference, $name, $version,  $versionScheme,  $source,  $summary,  $searchKey, $fullPath, $filename , $details , $entities, $links, $fromTrustedSource
}

<#
	Creates a new instance of a DyamicOption object
#>
function New-DynamicOption {
	param(
		[Parameter(Mandatory=$true)][Microsoft.OneGet.MetaProvider.PowerShell.OptionCategory] $category,
		[Parameter(Mandatory=$true)][string] $name,
		[Parameter(Mandatory=$true)][Microsoft.OneGet.MetaProvider.PowerShell.OptionType] $expectedType,
		[Parameter(Mandatory=$true)][bool] $isRequired,
		[System.Collections.ArrayList] $permittedValues = $null
	)

	if( -not $permittedValues ) {
		return New-Object -TypeName Microsoft.OneGet.MetaProvider.PowerShell.DynamicOption -ArgumentList $category,$name,  $expectedType, $isRequired
	}
	return New-Object -TypeName Microsoft.OneGet.MetaProvider.PowerShell.DynamicOption -ArgumentList $category,$name,  $expectedType, $isRequired, $permittedValues.ToArray()
}

<#
	Creates a new instance of a Feature object
#>
function New-Feature {
	param(
		[Parameter(Mandatory=$true)][string] $name,
		[System.Collections.ArrayList] $values = $null
	)

	if( -not $values ) {
		return New-Object -TypeName Microsoft.OneGet.MetaProvider.PowerShell.Feature -ArgumentList $name
	}
	return New-Object -TypeName Microsoft.OneGet.MetaProvider.PowerShell.Feature -ArgumentList $name, $values.ToArray()
}

<#
	Duplicates the $request object and overrides the client-supplied data with the specified values.
#>
function New-Request {
	param(
		[System.Collections.Hashtable] $options = $null,
		[System.Collections.ArrayList] $sources = $null,
		[PSCredential] $credential = $null
	)

	return $request.CloneRequest( $options, $sources, $credential )
}

function New-Entity {
	param(
		[Parameter(Mandatory=$true)][string] $name,
		[Parameter(Mandatory=$true)][string] $role,
        [string] $regId = $null,
        [string] $thumbprint= $null
	)

	$o = New-Object -TypeName Microsoft.OneGet.MetaProvider.PowerShell.Entity
	$o.Name = $name
	$o.Role = $role
	$o.regId = $regId
	$o.thumbprint = $thumbprint
	return $o
}

function New-Link {
	param(
		[Parameter(Mandatory=$true)][string] $HRef,
		[Parameter(Mandatory=$true)][string] $relationship,
		[string] $mediaType = $null,
		[string] $ownership = $null,
		[string] $use= $null,
		[string] $appliesToMedia= $null,
		[string] $artifact = $null
	)

	$o = New-Object -TypeName Microsoft.OneGet.MetaProvider.PowerShell.Link

	$o.HRef = $HRef
	$o.Relationship =$relationship
	$o.MediaType =$mediaType
	$o.Ownership =$ownership
	$o.Use = $use
	$o.AppliesToMedia = $appliesToMedia
	$o.Artifact = $artifact

	return $o
}