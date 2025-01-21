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
    public class DebugConfiguration : ConfigurationSection
    {
        public static DebugConfiguration Default { get { return new DebugConfiguration(); } }

        public static DebugConfiguration ShallowClone(DebugConfiguration configuration)
        {
            return Cloner.ShallowClone(configuration);
        }

        public DebugConfiguration() : base("Debug configuration for Pester. ⚠ Use at your own risk!")
        {
            ShowFullErrors = new BoolOption("Show full errors including Pester internal stack. This property is deprecated, and if set to true it will override Output.StackTraceVerbosity to 'Full'.", false);
            WriteDebugMessages = new BoolOption("Write Debug messages to screen.", false);
            WriteDebugMessagesFrom = new StringArrayOption("Write Debug messages from a given source, WriteDebugMessages must be set to true for this to work. You can use like wildcards to get messages from multiple sources, as well as * to get everything.", new string[] { "Discovery", "Skip", "Mock", "CodeCoverage" });
            ShowNavigationMarkers = new BoolOption("Write paths after every block and test, for easy navigation in VSCode.", false);
            ShowStartMarkers = new BoolOption("Write an indication when each test starts.", false);
            ReturnRawResultObject = new BoolOption("Returns unfiltered result object, this is for development only. Do not rely on this object for additional properties, non-public properties will be renamed without previous notice.", false);
        }

        public DebugConfiguration(IDictionary configuration) : this()
        {
            if (configuration != null)
            {
                configuration.AssignValueIfNotNull<bool>(nameof(ShowFullErrors), v => ShowFullErrors = v);
                configuration.AssignValueIfNotNull<bool>(nameof(WriteDebugMessages), v => WriteDebugMessages = v);
                configuration.AssignArrayIfNotNull<string>(nameof(WriteDebugMessagesFrom), v => WriteDebugMessagesFrom = v);
                configuration.AssignValueIfNotNull<bool>(nameof(ShowNavigationMarkers), v => ShowNavigationMarkers = v);
                configuration.AssignValueIfNotNull<bool>(nameof(ShowStartMarkers), v => ShowStartMarkers = v);
                configuration.AssignValueIfNotNull<bool>(nameof(ReturnRawResultObject), v => ReturnRawResultObject = v);
            }
        }

        private BoolOption _showFullErrors;
        private BoolOption _writeDebugMessages;
        private StringArrayOption _writeDebugMessagesFrom;
        private BoolOption _showNavigationMarkers;
        private BoolOption _showStartMarkers;
        private BoolOption _returnRawResultObject;

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
                    _showFullErrors = new BoolOption(_showFullErrors, value.Value);
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

        public StringArrayOption WriteDebugMessagesFrom
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
                    _writeDebugMessagesFrom = new StringArrayOption(_writeDebugMessagesFrom, value?.Value);
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
                    _showNavigationMarkers = new BoolOption(_showNavigationMarkers, value.Value);
                }
            }
        }

        public BoolOption ShowStartMarkers
        {
            get { return _showStartMarkers; }
            set
            {
                if (_showStartMarkers == null)
                {
                    _showStartMarkers = value;
                }
                else
                {
                    _showStartMarkers = new BoolOption(_showStartMarkers, value.Value);
                }
            }
        }

        public BoolOption ReturnRawResultObject
        {
            get { return _returnRawResultObject; }
            set
            {
                if (_returnRawResultObject == null)
                {
                    _returnRawResultObject = value;
                }
                else
                {
                    _returnRawResultObject = new BoolOption(_returnRawResultObject, value.Value);
                }
            }
        }
    }
}
