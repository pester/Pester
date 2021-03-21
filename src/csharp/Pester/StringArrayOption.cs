﻿using System.Linq;

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

namespace Pester
{
    public class StringArrayOption : Option<string[]>
    {
        public StringArrayOption(StringArrayOption option, string[] value) : base(option, value)
        {

        }

        public StringArrayOption(string description, string[] defaultValue) : base(description, defaultValue, defaultValue)
        {

        }

        public StringArrayOption(string description, string[] defaultValue, string[] value) : base(description, defaultValue, value)
        {

        }

        public StringArrayOption(string[] value) : base("", new string[0], value)
        {

        }

        public StringArrayOption(string value) : base("", new string[0], new string[] { value })
        {

        }

        public StringArrayOption(object[] value) : base("", new string[0], value.Select(oneValue => oneValue.ToString()).ToArray())
        {

        }

        public static implicit operator StringArrayOption(string[] value)
        {
            return new StringArrayOption(string.Empty, value, value);
        }

        public static implicit operator StringArrayOption(string value)
        {
            var array = new[] { value };
            return new StringArrayOption(string.Empty, array, array);
        }
    }
}
