function New-MockObject {
    <#
    .SYNOPSIS
        This function instantiates a .NET object from a type. The assembly for the particular type must be
        loaded.

    .PARAMETER Type
        The .NET type to create an object from.

    .EXAMPLE
        New-MockObject -Type 'System.Runtime.Serialization.Formatterservices'

        PS> $obj = [System.Runtime.Serialization.Formatterservices]::GetUninitializedObject('System.Management.Automation.ApplicationInfo')   
        PS> $obj | Get-Member                                                                                                                 

            TypeName: System.Management.Automation.ApplicationInfo

            Name               MemberType     Definition                                                                                                                              
            ----               ----------     ----------                                                                                                                              
            Equals             Method         bool Equals(System.Object obj)
            GetHashCode        Method         int GetHashCode()
            GetType            Method         type GetType()
            ResolveParameter   Method         System.Management.Automation.ParameterMetadata ResolveParameter(string name)
            ToString           Method         string ToString()
            CommandType        Property       System.Management.Automation.CommandTypes CommandType {get;}
            Definition         Property       string Definition {get;}
            Extension          Property       string Extension {get;}
            Module             Property       psmoduleinfo Module {get;}
            ModuleName         Property       string ModuleName {get;}
            Name               Property       string Name {get;}
            OutputType         Property       System.Collections.ObjectModel.ReadOnlyCollection[System.Management.Automation.PSTypeName] OutputType {get;}
            Parameters         Property       System.Collections.Generic.Dictionary[string,System.Management.Automation.ParameterMetadata] Parameters {get;}
            ParameterSets      Property       System.Collections.ObjectModel.ReadOnlyCollection[System.Management.Automation.CommandParameterSetInfo] ParameterSets {get;}
            Path               Property       string Path {get;}
            RemotingCapability Property       System.Management.Automation.RemotingCapability RemotingCapability {get;}
            Source             Property       string Source {get;}
            Version            Property       version Version {get;}                                                          
            Visibility         Property       System.Management.Automation.SessionStateEntryVisibility Visibility {get;set;}
            FileVersionInfo    ScriptProperty System.Object FileVersionInfo {get=[System.Diagnostics.FileVersionInfo]::getversioninfo( $this.Path );}                                 
            HelpUri            ScriptProperty System.Object HelpUri {get=$oldProgressPreference = $ProgressPreference...
    #>

    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [type]$Type
    )
    
    [System.Runtime.Serialization.Formatterservices]::GetUninitializedObject($Type)
    
}
