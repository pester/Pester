﻿using System.Collections;

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
    public class ShouldConfiguration : ConfigurationSection
    {

        private StringOption _errorAction;

        public static ShouldConfiguration Default { get { return new ShouldConfiguration(); } }

        public static ShouldConfiguration ShallowClone(ShouldConfiguration configuration)
        {
            return Cloner.ShallowClone(configuration);
        }

        public ShouldConfiguration() : base("Should configuration.")
        {
            ErrorAction = new StringOption("Controls if Should throws on error. Use 'Stop' to throw on error, or 'Continue' to fail at the end of the test.", "Stop");
        }

        public ShouldConfiguration(IDictionary configuration) : this()
        {
            if (configuration != null)
            {
                ErrorAction = configuration.GetObjectOrNull<string>("ErrorAction") ?? ErrorAction;
            }
        }

        public StringOption ErrorAction
        {
            get { return _errorAction; }
            set
            {
                if (_errorAction == null)
                {
                    _errorAction = value;
                }
                else
                {
                    _errorAction = new StringOption(_errorAction, value?.Value);
                }
            }
        }
    }
}
