
using Pester;
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

namespace Pester {
    public abstract class Option<T>
    {
        public Option(Option<T> option, T value) : this(option.Description, option.Default, value)
        {

        }

        public Option(string description, T defaultValue, T value)
        {
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

    public class StringOption : Option<string>
    {
        public StringOption(string description, string defaultValue) : base(description, defaultValue, defaultValue)
        {

        }

        public StringOption(string description, string defaultValue, string value) : base(description, defaultValue, value)
        {

        }

        public static implicit operator StringOption(string value)
        {
            return new StringOption(string.Empty, value, value);
        }
    }

    public class BoolOption : Option<bool>
    {
        public BoolOption(BoolOption option, bool value) : base(option, value)
        {

        }

        public BoolOption(string description, bool defaultValue) : base(description, defaultValue, defaultValue)
        {

        }

        public BoolOption(string description, bool defaultValue, bool value) : base(description, defaultValue, value)
        {

        }

        public static implicit operator BoolOption(bool value)
        {
            return new BoolOption(string.Empty, value, value);
        }
    }

    public class IntOption : Option<int>
    {
        public IntOption(string description, int defaultValue) : base(description, defaultValue, defaultValue)
        {

        }

        public IntOption(string description, int defaultValue, int value) : base(description, defaultValue, value)
        {

        }

        public static implicit operator IntOption(int value)
        {
            return new IntOption(string.Empty, value, value);
        }
    }

    public class DecimalOption : Option<decimal>
    {
        public DecimalOption(string description, decimal defaultValue) : base(description, defaultValue, defaultValue)
        {

        }

        public DecimalOption(string description, decimal defaultValue, decimal value) : base(description, defaultValue, value)
        {

        }

        public static implicit operator DecimalOption(decimal value)
        {
            return new DecimalOption(string.Empty, value, value);
        }
    }

    public abstract class ConfigurationSection
    {
        private string _description;
        public ConfigurationSection(string description)
        {
            _description = description;
        }

        public override string ToString()
        {
            return _description;
        }
    }


    internal static class DictionaryExtensions
    {
        public static T? GetValueOrNull<T>(this IDictionary dictionary, string key) where T : struct
        {
            return dictionary.Contains(key) ? dictionary[key] as T? : null;
        }

        public static T GetObjectOrNull<T>(this IDictionary dictionary, string key) where T : class
        {
            return dictionary.Contains(key) ? dictionary[key] as T : null;
        }

        public static IDictionary GetIDictionaryOrNull(this IDictionary dictionary, string key)
        {
            return dictionary.Contains(key) ? dictionary[key] as IDictionary : null;
        }
    }
    public class ShouldConfiguration : ConfigurationSection
    {
        public static ShouldConfiguration Default { get { return new ShouldConfiguration(); } }

        private StringOption _errorAction;

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
                    _errorAction = new StringOption(_errorAction.Description, _errorAction.Default, value.Value);
                }
            }
        }
    }

    public class DebugConfiguration : ConfigurationSection
    {
        public static DebugConfiguration Default { get { return new DebugConfiguration(); } }
        public DebugConfiguration() : base("Debug configuration for Pester. ⚠ Use at your own risk!")
        {
            ShowFullErrors = new BoolOption("Show full errors including Pester internal stack.", false);
            WriteDebugMessages = new BoolOption("Write Debug messages to screen.", false);
            WriteDebugMessagesFrom = new StringOption("Write Debug messages from a given source, WriteDebugMessages must be set to true for this to work. You can use like wildcards to get messages from multiple sources, as well as * to get everything.", "*");
            ShowNavigationMarkers = new BoolOption("Write paths after every block and test, for easy navigation in VSCode", false);
        }

        public DebugConfiguration(IDictionary configuration) : this()
        {
            if (configuration != null)
            {
                ShowFullErrors = configuration.GetValueOrNull<bool>("ShowFullErrors") ?? ShowFullErrors;
                WriteDebugMessages = configuration.GetValueOrNull<bool>("WriteDebugMessages") ?? WriteDebugMessages;
                WriteDebugMessagesFrom = configuration.GetObjectOrNull<string>("WriteDebugMessagesFrom") ?? WriteDebugMessagesFrom;
                ShowNavigationMarkers = configuration.GetValueOrNull<bool>("ShowNavigationMarkers") ?? ShowNavigationMarkers;
            }
        }

        private BoolOption _showFullErrors;
        private BoolOption _writeDebugMessages;
        private StringOption _writeDebugMessagesFrom;
        private BoolOption _showNavigationMarkers;

        public BoolOption ShowFullErrors
        {
            get { return _showFullErrors; }
            set
            {
                if (_showFullErrors == null)
                {
                    _showFullErrors = value;
                }
                else
                {
                    _showFullErrors = new BoolOption(_showFullErrors.Description, _showFullErrors.Default, value.Value);
                }
            }
        }

        public BoolOption WriteDebugMessages
        {
            get { return _writeDebugMessages; }
            set
            {
                if (_writeDebugMessages == null)
                {
                    _writeDebugMessages = value;
                }
                else
                {
                    _writeDebugMessages = new BoolOption(_writeDebugMessages, value.Value);
                }
            }
        }

        public StringOption WriteDebugMessagesFrom
        {
            get { return _writeDebugMessagesFrom; }
            set
            {
                if (_writeDebugMessagesFrom == null)
                {
                    _writeDebugMessagesFrom = value;
                }
                else
                {
                    _writeDebugMessagesFrom = new StringOption(_writeDebugMessagesFrom.Description, _writeDebugMessagesFrom.Default, value.Value);
                }
            }
        }

        public BoolOption ShowNavigationMarkers
        {
            get { return _showNavigationMarkers; }
            set
            {
                if (_showNavigationMarkers == null)
                {
                    _showNavigationMarkers = value;
                }
                else
                {
                    _showNavigationMarkers = new BoolOption(_showNavigationMarkers.Description, _showNavigationMarkers.Default, value.Value);
                }
            }
        }
    }
}

public class PesterConfiguration
{
    public static PesterConfiguration Default { get { return new PesterConfiguration(); } }
    public PesterConfiguration(IDictionary configuration)
    {
        Should = new ShouldConfiguration(configuration.GetIDictionaryOrNull("Should"));
        Debug = new DebugConfiguration(configuration.GetIDictionaryOrNull("Debug"));
    }

    public PesterConfiguration()
    {
        Should = new ShouldConfiguration();
        Debug = new DebugConfiguration();
    }

    public ShouldConfiguration Should { get; set; }
    public DebugConfiguration Debug { get; set; }
}
