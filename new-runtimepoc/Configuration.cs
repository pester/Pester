using Pester;
using System.Collections;
using System.Collections.Generic;
using System.Management.Automation;

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
        public StringOption(StringOption option, string value) : base(option, value)
        {

        }
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

        public static implicit operator StringArrayOption(string[] value)
        {
            return new StringArrayOption(string.Empty, value, value);
        }
    }

    public class ScriptBlockArrayOption : Option<ScriptBlock[]>
    {
        public ScriptBlockArrayOption(ScriptBlockArrayOption option, ScriptBlock[] value) : base(option, value)
        {

        }

        public ScriptBlockArrayOption(string description, ScriptBlock[] defaultValue) : base(description, defaultValue, defaultValue)
        {

        }

        public ScriptBlockArrayOption(string description, ScriptBlock[] defaultValue, ScriptBlock[] value) : base(description, defaultValue, value)
        {

        }

        public static implicit operator ScriptBlockArrayOption(ScriptBlock[] value)
        {
            return new ScriptBlockArrayOption(string.Empty, value, value);
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

    public class CodeCoverageConfiguration : ConfigurationSection
    {
        public static CodeCoverageConfiguration Default { get { return new CodeCoverageConfiguration(); } }
        public CodeCoverageConfiguration() : base("CodeCoverage configuration.")
        {
            Enabled = new BoolOption("Enable CodeCoverage.", false);
            OutputFormat = new StringOption("Format to use for code coverage report. Possible values: JaCoCo", "JaCoCo");
            OutputPath = new StringOption("Path relative to the current directory where code coverage report is saved.", "coverage.xml");
        }

        public CodeCoverageConfiguration(IDictionary configuration) : this()
        {
            if (configuration != null)
            {
                Enabled = configuration.GetValueOrNull<bool>("Enabled") ?? Enabled;
                OutputFormat = configuration.GetObjectOrNull<string>("OutputFormat") ?? OutputFormat;
                OutputPath = configuration.GetObjectOrNull<string>("OutputPath") ?? OutputPath;
            }
        }

        private BoolOption _enabled;
        private StringOption _outputFormat;
        private StringOption _outputPath;

        public BoolOption Enabled
        {
            get { return _enabled; }
            set
            {
                if (_enabled == null)
                {
                    _enabled = value;
                }
                else
                {
                    _enabled = new BoolOption(_enabled, value.Value);
                }
            }
        }

        public StringOption OutputFormat
        {
            get { return _outputFormat; }
            set
            {
                if (_outputFormat == null)
                {
                    _outputFormat = value;
                }
                else
                {
                    _outputFormat = new StringOption(_outputFormat, value.Value);
                }
            }
        }

        public StringOption OutputPath
        {
            get { return _outputPath; }
            set
            {
                if (_outputPath == null)
                {
                    _outputPath = value;
                }
                else
                {
                    _outputPath = new StringOption(_outputPath, value.Value);
                }
            }
        }
    }

    public class TestResultConfiguration : ConfigurationSection
    {
        public static TestResultConfiguration Default { get { return new TestResultConfiguration(); } }
        public TestResultConfiguration() : base("TestResult configuration.")
        {
            Enabled = new BoolOption("Enable TestResult.", false);
            OutputFormat = new StringOption("Format to use for test result report. Possible values: NUnit2.5", "NUnit2.5");
            OutputPath = new StringOption("Path relative to the current directory where test result report is saved.", "testResults.xml");
            TestSuiteName = new StringOption("Set the name assigned to the root 'test-suite' element.", "Pester");
        }

        public TestResultConfiguration(IDictionary configuration) : this()
        {
            if (configuration != null)
            {
                Enabled = configuration.GetValueOrNull<bool>("Enabled") ?? Enabled;
                OutputFormat = configuration.GetObjectOrNull<string>("OutputFormat") ?? OutputFormat;
                OutputPath = configuration.GetObjectOrNull<string>("OutputPath") ?? OutputPath;
            }
        }

        private BoolOption _enabled;
        private StringOption _outputFormat;
        private StringOption _outputPath;
        private StringOption _testSuiteName;

        public BoolOption Enabled
        {
            get { return _enabled; }
            set
            {
                if (_enabled == null)
                {
                    _enabled = value;
                }
                else
                {
                    _enabled = new BoolOption(_enabled, value.Value);
                }
            }
        }

        public StringOption OutputFormat
        {
            get { return _outputFormat; }
            set
            {
                if (_outputFormat == null)
                {
                    _outputFormat = value;
                }
                else
                {
                    _outputFormat = new StringOption(_outputFormat, value.Value);
                }
            }
        }

        public StringOption OutputPath
        {
            get { return _outputPath; }
            set
            {
                if (_outputPath == null)
                {
                    _outputPath = value;
                }
                else
                {
                    _outputPath = new StringOption(_outputPath, value.Value);
                }
            }
        }

        public StringOption TestSuiteName
        {
            get { return _testSuiteName; }
            set
            {
                if (_testSuiteName ==null)
                {
                    _testSuiteName = value;
                }
                else
                {
                    _testSuiteName = new StringOption(_testSuiteName, value.Value);
                }
            }
        }
    }
}

public class PesterConfiguration
{
    private BoolOption _exit;
    private StringArrayOption _path;
    private ScriptBlockArrayOption _scriptBlock;
    public static PesterConfiguration Default { get { return new PesterConfiguration(); } }
    public PesterConfiguration(IDictionary configuration)
    {
        if (configuration != null)
        {
            Exit = configuration.GetValueOrNull<bool>("Exit") ?? Exit;
            Path = configuration.GetObjectOrNull<string[]>("Path") ?? Path;
            CodeCoverage = new CodeCoverageConfiguration(configuration.GetIDictionaryOrNull("CodeCoverage"));
            TestResult = new TestResultConfiguration(configuration.GetIDictionaryOrNull("TestResult"));
            Should = new ShouldConfiguration(configuration.GetIDictionaryOrNull("Should"));
            Debug = new DebugConfiguration(configuration.GetIDictionaryOrNull("Debug"));
        }
    }

    public PesterConfiguration()
    {
        Exit = false;
        Path = new string[0];
        ScriptBlock = new ScriptBlock[0];
        CodeCoverage = new CodeCoverageConfiguration();
        TestResult = new TestResultConfiguration();
        Should = new ShouldConfiguration();
        Debug = new DebugConfiguration();
    }


    public BoolOption Exit
    {
        get { return _exit; }
        set
        {
            if (_exit == null)
            {
                _exit = value;
            }
            else
            {
                _exit = new BoolOption(_exit, value.Value);
            }
        }
    }

    public StringArrayOption Path
    {
        get { return _path; }
        set
        {
            if (_path == null)
            {
                _path = value;
            }
            else
            {
                _path = new StringArrayOption(_path, value.Value);
            }
        }
    }

    public ScriptBlockArrayOption ScriptBlock
    {
        get { return _scriptBlock; }
        set
        {
            if (_scriptBlock == null)
            {
                _scriptBlock = value;
            }
            else
            {
                _scriptBlock = new ScriptBlockArrayOption(_scriptBlock, value.Value);
            }
        }
    }

    public CodeCoverageConfiguration CodeCoverage { get; set; }
    public TestResultConfiguration TestResult { get; set; }
    public ShouldConfiguration Should { get; set; }
    public DebugConfiguration Debug { get; set; }
}
