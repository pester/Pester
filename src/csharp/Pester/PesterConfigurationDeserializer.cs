using System;
using System.Collections;
using System.Management.Automation;
using System.Reflection;
using Pester;

public class PesterConfigurationDeserializer : PSTypeConverter
{
    public override bool CanConvertFrom(object sourceValue, Type destinationType)
    {
        if (sourceValue is not PSObject)
            return false;

        return ((PSObject)sourceValue).TypeNames.Contains("Deserialized.PesterConfiguration");
    }

    public override object ConvertFrom(object sourceValue, Type destinationType, IFormatProvider formatProvider, bool ignoreCase)
    {
        return ConvertToPesterConfiguration(sourceValue);
    }

    public override bool CanConvertTo(object sourceValue, Type destinationType)
    {
        throw new NotImplementedException();
    }

    public override object ConvertTo(object sourceValue, Type destinationType, IFormatProvider formatProvider, bool ignoreCase)
    {
        throw new NotImplementedException();
    }

    private PesterConfiguration ConvertToPesterConfiguration(object sourceValue)
    {
        if (sourceValue is IDictionary dictionary)
            return new PesterConfiguration(dictionary);

        return new PesterConfiguration(ConvertToConfigurationHashtable((PSObject)sourceValue));
    }

    private Hashtable ConvertToConfigurationHashtable(PSObject sourceConfiguration)
    {
        Hashtable configuration = new();

        foreach (var property in sourceConfiguration.Properties)
        {
            configuration.Add(
                property.Name,
                ConvertToSectionHashtable(
                    (PSObject)property.Value,
                    property.Name
                )
            );
        }

        return configuration;
    }

    private Hashtable ConvertToSectionHashtable(PSObject sourceSection, string sectionName)
    {
        Hashtable configurationSection = new();

        foreach (var property in sourceSection.Properties)
        {
            var IsModified = ((PSObject)property.Value).Properties["IsModified"];

            // Doing this instead of IsModified -> Add to be compatible with saved PesterConfigurations from previous versions
            // Consider rewriting in next major release
            if (IsModified != null && !((bool)IsModified.Value)) {
                continue;
            }

            configurationSection.Add(
                property.Name,
                GetPropertyValue(
                    (PSObject)property.Value,
                    sectionName,
                    property.Name
                )
            );
        }

        return configurationSection;
    }

    private object GetPropertyValue(PSObject sourceItem, string sectionName, string propertyName)
    {
        var value = sourceItem.Properties["Value"].Value;

        if (value is PSObject pso)
            value = pso.BaseObject;

        if (value == null)
            return null;

        var expectedType = GetExpectedType(sectionName, propertyName);

        if (expectedType == typeof(ScriptBlock[]))
        {
            ArrayList scriptBlocks = new();
            foreach (string scriptBlock in (ArrayList)value)
            {
                scriptBlocks.Add(ScriptBlock.Create(scriptBlock));
            }
            value = scriptBlocks;
        }

        if (expectedType == typeof(ContainerInfo[]))
        {
            ArrayList containers = new();
            foreach (PSObject container in (ArrayList)value)
            {
                var containerInfo = Pester.ContainerInfo.Create();
                containerInfo.Type = (string)container.Properties["Type"].Value;
                containerInfo.Item = container.Properties["Item"].Value;
                containerInfo.Data = container.Properties["Data"].Value;

                containers.Add(containerInfo);
            }
            value = containers;
        }

        if (value is ArrayList list)
            value = list.ToArray();

        return value;
    }

    private Type GetExpectedType(string sectionName, string propertyName)
    {
        return typeof(PesterConfiguration).
            GetProperty(sectionName).
            PropertyType.
            GetProperty(propertyName).
            PropertyType.
            GetProperty("Value").
            PropertyType;
    }
}
