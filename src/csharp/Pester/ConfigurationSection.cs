// those types implement Pester configuration in a way that allows it to show information about each item
// in the powershell console without making it difficult to use. there are two tricks being used:
// - constructor taking IDictionary (most likely a hashtable) that will populate the object,
//   this allows the object to be constructed from a hashtable simply by casting to the type
//   both implicitly and explicitly, so the user does not have to care about what types are used
//   but will still get the benefit of the data annotation in the object. Usage is like this:
//   `$config.Debug = @{ WriteDebugMessages = $true; WriteDebugMessagesFrom = "Mock*" }`, which
//   will populate the config with the given values while keeping all other values to the default.
// - to be able to assign values like this: `$config.Should.ErrorAction = 'Continue'` but still
//   get the documentation when accessing the property, we use implicit casting to get an instance of
//   StringOption, and then populate it from the option object that is already assigned to the property
//
// lastly most of the types go to Pester namespace to keep them from the global namespace because they are
// simple to use by implicit casting, with the only exception of PesterConfiguration because that is helpful
// to have in "type accelerator" form, but without the hassle of actually adding it as a type accelerator
// that way you can easily do `[PesterConfiguration]::Default` and then inspect it, or cast a hashtable to it

using System.Reflection;

namespace Pester
{
    public abstract class ConfigurationSection
    {
        private readonly string _description;
        public ConfigurationSection(string description)
        {
            _description = description;
        }

        public override string ToString()
        {
            return _description;
        }

        /// <summary>
        /// If this section has an Enabled option that was not explicitly modified,
        /// and any other option in the section was modified, auto-enable the section.
        /// </summary>
        public void ResolveEnabled()
        {
            var enabledProperty = GetType().GetProperty("Enabled", BindingFlags.Public | BindingFlags.Instance);
            if (enabledProperty == null || enabledProperty.PropertyType != typeof(BoolOption))
                return;

            var enabled = (BoolOption)enabledProperty.GetValue(this);
            if (enabled == null || enabled.IsModified)
                return;

            foreach (var property in GetType().GetProperties(BindingFlags.Public | BindingFlags.Instance))
            {
                if (property.Name == "Enabled")
                    continue;

                if (!typeof(Option).IsAssignableFrom(property.PropertyType))
                    continue;

                var option = (Option)property.GetValue(this);
                if (option != null && option.IsModified)
                {
                    enabledProperty.SetValue(this, (BoolOption)true);
                    return;
                }
            }
        }
    }
}
