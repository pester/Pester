##############################################################################################
# Taken from http://gallery.technet.microsoft.com/scriptcenter/2f6f0541-d152-4474-a8c1-b441d7424454
# Written by Justin Yancey
##############################################################################################

#<function name="Validate-Xml"> 
#<description>A function used to validate an XML object against a given schema</description> 
#<parameters> 
#    <parameter name="xml" type="XmlDocument" mandatory="true" position="0" pipeline="true" /> 
#    <parameter name="schema" type="String" mandatory="true" position="1" pipeline="false" /> 
#</parameters> 
#<returns>Array</returns> 
#<body> 
 
Function Validate-Xml{ 
    param(     
        [Parameter( 
            Mandatory = $true, 
            Position = 0, 
            ValueFromPipeline = $true, 
            ValueFromPipelineByPropertyName = $true)] 
        [xml]$xml, 
        [Parameter( 
            Mandatory = $true, 
            Position = 1, 
            ValueFromPipeline = $false)] 
        [string]$schema 
        ) 
 
    #<c>Declare the array to hold our error objects</c> 
    $validationerrors = @() 
         
    #<c>Check to see if we have defined our namespace cache variable, 
    #and create it if it doesnt exist. We do this in case we want to make 
    #lots and lots of calls to this function, to save on excessive file IO.</c> 
    if (-not $schemas){ ${GLOBAL:schemas} = @{} } 
     
    #<c>Check to see if the namespace is already in the cache,if not then add it</c> 
    #<choose> 
    #<if test="Is schema in cache"> 
    if (-not $schemas[$schema]) { 
        #<c>Read in the schema file</c> 
        [xml]$xmlschema = Get-Content $schema 
        #<c>Extract the targetNamespace from the schema</c> 
        $namespace = $xmlschema.get_DocumentElement().targetNamespace 
        #<c>Add the schema/namespace entry to the global hashtable</c> 
        $schemas.Add($schema,$namespace) 
        #</if> 
    } else { 
        #<else> 
        #<c>Pull the namespace from the schema cache</c> 
        $namespace = $schemas[$schema] 
    } 
    #</else><choose> 
 
    #<c>Define the script block that will act as the validation event handler</c> 
$code = @' 
    param($sender,$a) 
    $ex = $a.Exception 
    #<c>Trim out the useless,irrelevant parts of the message</c> 
    $msg = $ex.Message -replace " in namespace 'http.*?'","" 
    #<c>Create the custom error object using a hashtable</c> 
    $properties = @{LineNumber=$ex.LineNumber; LinePosition=$ex.LinePosition; Message=$msg} 
    $o = New-Object PSObject -Property $properties 
    #<c>Add the object to the $validationerrors array</c> 
    $validationerrors += $o 
'@ 
    #<c>Convert the code block to as ScriptBlock</c> 
    $validationEventHandler = [scriptblock]::Create($code) 
     
    #<c>Create a new XmlReaderSettings object</c> 
    $rs = new-object System.Xml.XmlreaderSettings 
    #<c>Load the schema into the XmlReaderSettings object</c> 
    [Void]$rs.schemas.add($namespace,(new-object System.Xml.xmltextreader($schema))) 
    #<c>Instruct the XmlReaderSettings object to use Schema validation</c> 
    $rs.validationtype = "Schema" 
    $rs.ConformanceLevel = "Auto" 
    #<c>Add the scriptblock as the ValidationEventHandler</c> 
    $rs.add_ValidationEventHandler($validationEventHandler) 
     
    #<c>Create a temporary file and save the Xml into it</c> 
    $xmlfile = [System.IO.Path]::GetTempFileName() 
    $xml.Save($xmlfile) 
     
    #<c>Create the XmlReader object using the settings defined previously</c> 
    $reader = [System.Xml.XmlReader]::Create($xmlfile,$rs) 
     
    #<c>Temporarily set the ErrorActionPreference to SilentlyContinue, 
    #as we want to use our validation event handler to handle errors</c> 
    $previousErrorActionPreference = $ErrorActionPreference 
    $ErrorActionPreference = "SilentlyContinue" 
     
    #<c>Read the Xml using the XmlReader</c> 
    while ($reader.read()) {$null} 
    #<c>Close the reader</c> 
    $reader.close() 
     
    #<c>Delete the temporary file</c> 
    Remove-Item $xmlfile 
     
    #<c>Reset the ErrorActionPreference back to the previous value</c> 
    $ErrorActionPreference = $previousErrorActionPreference  
     
    #<c>Return the array of validation errors</c> 
    return $validationerrors 
} 
#</body></function> 
