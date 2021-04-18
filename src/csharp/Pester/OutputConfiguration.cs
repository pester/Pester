﻿using System;
using System.Collections;

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
    public class OutputConfiguration : ConfigurationSection
    {
        private StringOption _verbosity;

        public static OutputConfiguration Default { get { return new OutputConfiguration(); } }
        public static OutputConfiguration ShallowClone(OutputConfiguration configuration)
        {
            return Cloner.ShallowClone(configuration);
        }

        public OutputConfiguration(IDictionary configuration) : this()
        {
            if (configuration != null)
            {
                Verbosity = configuration.GetObjectOrNull<string>("Verbosity") ?? Verbosity;
            }
        }

        public OutputConfiguration() : base("Output configuration")
        {
            Verbosity = new StringOption("The verbosity of output, options are None, Normal, Detailed and Diagnostic.", "Normal");
        }

        public StringOption Verbosity
        {
            get { return _verbosity; }
            set
            {
                if (_verbosity == null)
                {
                    _verbosity = value;
                }
                else
                {
                    _verbosity = new StringOption(_verbosity, FixMinimal(value?.Value));
                }
            }
        }

        private string FixMinimal(string value)
        {
            return string.Equals(value, "Minimal", StringComparison.OrdinalIgnoreCase) ? "Normal" : value;
        }
    }
}
