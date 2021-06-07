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
            foreach ($value in $configurationSection.Value.PSObject.Properties) {
                $configurationItem = $configuration.($configurationSection.Name).($value.Name)

                if ($configurationItem -is [Pester.ScriptBlockArrayOption]) {
                    $configurationItem.Value = foreach ($string in $sourceValue.($configurationSection.Name).($value.Name).Value) {
                        [ScriptBlock]::Create($string)
                    }
                }
                else {
                    $configurationItem.Value = $sourceValue.($configurationSection.Name).($value.Name).Value
                }
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
