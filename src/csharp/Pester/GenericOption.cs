﻿// those types implement Pester configuration in a way that allows it to show information about each item
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
    public abstract class Option<T> : Option
    {
        public Option(Option<T> option, T value) : this(option.Description, option.Default, value)
        {
            _isOriginalValue = false;
        }

        public Option(string description, T defaultValue, T value)
        {
            _isOriginalValue = true;
            Default = defaultValue;
            Value = value;
            Description = description;
        }

        public T Default { get; private set; }
        public string Description { get; private set; }
        public T Value { get; set; }

        public override string ToString()
        {
            return string.Format("{0} ({1}, default: {2})", Description, Value, Default);
        }
    }
}
