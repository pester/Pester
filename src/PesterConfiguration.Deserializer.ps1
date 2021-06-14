using namespace System.Collections
using namespace System.Management.Automation

class PesterConfigurationDeserializer : PSTypeConverter {
    [bool] CanConvertFrom(
        [object] $sourceValue,
        [Type] $destinationType
    ) {
        return $sourceValue.PSTypeNames -contains 'Deserialized.PesterConfiguration'
    }

    [object] ConvertFrom(
        [object] $sourceValue,
        [Type] $destinationType,
        [IFormatProvider] $formatProvider,
        [bool] $ignoreCase
    ) {
        if ($sourceValue -is [IDictionary]) {
            return [PesterConfiguration]$sourceValue
        }

        $configuration = [PesterConfiguration]::new()
        foreach ($configurationSection in $configuration.PSObject.Properties) {
            $configurationToSet = $configuration.($configurationSection.Name)

            foreach ($value in $configurationSection.Value.PSObject.Properties) {
                $configurationItem = $configuration.($configurationSection.Name).($value.Name)

                if ($configurationItem -is [Pester.ScriptBlockArrayOption]) {
                    $valueToSet = foreach ($string in $sourceValue.($configurationSection.Name).($value.Name).Value) {
                        [ScriptBlock]::Create($string)
                    }
                }
                else {
                    $valueToSet = $sourceValue.($configurationSection.Name).($value.Name).Value
                }

                $configurationToSet.($value.Name) = $valueToSet | Write-Output
            }
        }

        return $configuration
    }

    [bool] CanConvertTo(
        [object] $sourceValue,
        [Type] $destinationType
    ) {
        throw [NotImplementedException]::new()
    }

    [object] ConvertTo(
        [object] $sourceValue,
        [Type] $destinationType,
        [IFormatProvider] $formatProvider,
        [bool] $ignoreCase
    ) {
        throw [NotImplementedException]::new()
    }
}

Update-TypeData -TypeName PesterConfiguration -TypeConverter 'PesterConfigurationDeserializer' -SerializationDepth 5 -Force
Update-TypeData -TypeName 'Deserialized.PesterConfiguration' -TargetTypeForDeserialization PesterConfiguration -Force
