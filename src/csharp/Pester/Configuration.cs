using Pester;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
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
    internal static class Cloner
    {
        public static T ShallowClone<T>(T obj) where T : new()
        {
            var cfg = new T();
            var properties = typeof(T).GetProperties().ToList();

            foreach (var p in properties.Where(p => p.CanRead && p.CanWrite))
            {
                var value = p.GetValue(obj);
                p.SetValue(cfg, value);
            }

            return cfg;
        }
    }

    internal static class Merger
    {
        public static T Merge<T>(T configuration, T @override) where T : new()
        {
            var cfg = new T();
            var properties = typeof(T).GetProperties().ToList();

            foreach (var p in properties.Where(p => p.CanRead && p.CanWrite))
            {
                object value;
                var overrideValue = p.GetValue(@override);
                if (!((Option)overrideValue).IsOriginalValue())
                {
                    value = overrideValue;
                }
                else
                {
                    value = p.GetValue(configuration);
                }

                p.SetValue(cfg, value);
            }

            return cfg;
        }
    }

    public abstract class Option
    {
        protected bool _isOriginalValue;

        public bool IsOriginalValue()
        {
            return _isOriginalValue;
        }
    }

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
        public IntOption(IntOption option, int value) : base(option, value)
        {

        }

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
        public DecimalOption(DecimalOption option, decimal value) : base(option, value)
        {

        }

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

        public ScriptBlockArrayOption(object[] value) : base("", new ScriptBlock[0], value.Cast<ScriptBlock>().ToArray())
        {

        }

        public ScriptBlockArrayOption(ScriptBlock[] value) : base("", new ScriptBlock[0], value)
        {

        }

        public ScriptBlockArrayOption(ScriptBlock value) : this(new ScriptBlock[] { value })
        {

        }

        public static implicit operator ScriptBlockArrayOption(ScriptBlock[] value)
        {
            return new ScriptBlockArrayOption(string.Empty, value, value);
        }

        public static implicit operator ScriptBlockArrayOption(ScriptBlock value)
        {
            var array = new[] { value };
            return new ScriptBlockArrayOption(string.Empty, array, array);
        }
    }

    public class ContainerInfoArrayOption : Option<ContainerInfo[]>
    {
        public ContainerInfoArrayOption(ContainerInfoArrayOption option, ContainerInfo[] value) : base(option, value)
        {

        }

        public ContainerInfoArrayOption(string description, ContainerInfo[] defaultValue) : base(description, defaultValue, defaultValue)
        {

        }

        public ContainerInfoArrayOption(string description, ContainerInfo[] defaultValue, ContainerInfo[] value) : base(description, defaultValue, value)
        {

        }

        public ContainerInfoArrayOption(object[] value) : base("", new ContainerInfo[0], value.Cast<ContainerInfo>().ToArray())
        {

        }

        public ContainerInfoArrayOption(ContainerInfo[] value) : base("", new ContainerInfo[0], value)
        {

        }

        public ContainerInfoArrayOption(List<object> value) : base("", new ContainerInfo[0], value.Cast<ContainerInfo>().ToArray())
        {

        }

        public ContainerInfoArrayOption(List<ContainerInfo> value) : base("", new ContainerInfo[0], value.ToArray())
        {

        }

        public ContainerInfoArrayOption(ContainerInfo value) : this(new ContainerInfo[] { value })
        {

        }

        public static implicit operator ContainerInfoArrayOption(ContainerInfo[] value)
        {
            return new ContainerInfoArrayOption(string.Empty, value, value);
        }

        public static implicit operator ContainerInfoArrayOption(ContainerInfo value)
        {
            var array = new[] { value };
            return new ContainerInfoArrayOption(string.Empty, array, array);
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
            if (!dictionary.Contains(key))
                return null;

            if (typeof(T) == typeof(string))
                if (dictionary[key] is PSObject o)
                    return (T) Convert.ChangeType(o.ToString(), typeof(string));

            return dictionary[key] as T;
        }

        public static IDictionary GetIDictionaryOrNull(this IDictionary dictionary, string key)
        {
            return dictionary.Contains(key) ? dictionary[key] as IDictionary : null;
        }

        public static T[] GetArrayOrNull<T>(this IDictionary dictionary, string key) where T : class
        {
            if (!dictionary.Contains(key))
                return null;
            var value = dictionary[key];

            if (value.GetType() == typeof(T[]))
            {
                return (T[])value;
            }

            if (value.GetType() == typeof(object[]))
            {
                try
                {
                    return ((object[])value).Cast<T>().ToArray();
                }
                catch { }
            }

            if (value.GetType() == typeof(T))
            {
                return new T[] { (T)value };
            }

            return null;
        }
    }

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

    public class DebugConfiguration : ConfigurationSection
    {
        public static DebugConfiguration Default { get { return new DebugConfiguration(); } }

        public static DebugConfiguration ShallowClone(DebugConfiguration configuration)
        {
            return Cloner.ShallowClone(configuration);
        }

        public DebugConfiguration() : base("Debug configuration for Pester. ⚠ Use at your own risk!")
        {
            ShowFullErrors = new BoolOption("Show full errors including Pester internal stack.", false);
            WriteDebugMessages = new BoolOption("Write Debug messages to screen.", false);
            WriteDebugMessagesFrom = new StringArrayOption("Write Debug messages from a given source, WriteDebugMessages must be set to true for this to work. You can use like wildcards to get messages from multiple sources, as well as * to get everything.", new string[] { "Discovery", "Skip", "Filter", "Mock", "CodeCoverage" });
            ShowNavigationMarkers = new BoolOption("Write paths after every block and test, for easy navigation in VSCode.", false);
            ReturnRawResultObject = new BoolOption("Returns unfiltered result object, this is for development only. Do not rely on this object for additional properties, non-public properties will be renamed without previous notice.", false);
        }

        public DebugConfiguration(IDictionary configuration) : this()
        {
            if (configuration != null)
            {
                ShowFullErrors = configuration.GetValueOrNull<bool>("ShowFullErrors") ?? ShowFullErrors;
                WriteDebugMessages = configuration.GetValueOrNull<bool>("WriteDebugMessages") ?? WriteDebugMessages;
                WriteDebugMessagesFrom = configuration.GetArrayOrNull<string>("WriteDebugMessagesFrom") ?? WriteDebugMessagesFrom;
                ShowNavigationMarkers = configuration.GetValueOrNull<bool>("ShowNavigationMarkers") ?? ShowNavigationMarkers;
                ReturnRawResultObject = configuration.GetValueOrNull<bool>("ReturnRawResultObject") ?? ReturnRawResultObject;
            }
        }

        private BoolOption _showFullErrors;
        private BoolOption _writeDebugMessages;
        private StringArrayOption _writeDebugMessagesFrom;
        private BoolOption _showNavigationMarkers;
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

    public class CodeCoverageConfiguration : ConfigurationSection
    {
        private BoolOption _enabled;
        private StringOption _outputFormat;
        private StringOption _outputPath;
        private StringOption _outputEncoding;
        private StringArrayOption _path;
        private BoolOption _excludeTests;

        public static CodeCoverageConfiguration Default { get { return new CodeCoverageConfiguration(); } }

        public static CodeCoverageConfiguration ShallowClone(CodeCoverageConfiguration configuration)
        {
            return Cloner.ShallowClone(configuration);
        }
        public CodeCoverageConfiguration() : base("CodeCoverage configuration.")
        {
            Enabled = new BoolOption("Enable CodeCoverage.", false);
            OutputFormat = new StringOption("Format to use for code coverage report. Possible values: JaCoCo", "JaCoCo");
            OutputPath = new StringOption("Path relative to the current directory where code coverage report is saved.", "coverage.xml");
            OutputEncoding = new StringOption("Encoding of the output file.", "UTF8");
            Path = new StringArrayOption("Directories or files to be used for codecoverage, by default the Path(s) from general settings are used, unless overridden here.", new string[0]);
            ExcludeTests = new BoolOption("Exclude tests from code coverage. This uses the TestFilter from general configuration.", true);

        }

        public CodeCoverageConfiguration(IDictionary configuration) : this()
        {
            if (configuration != null)
            {
                Enabled = configuration.GetValueOrNull<bool>("Enabled") ?? Enabled;
                OutputFormat = configuration.GetObjectOrNull<string>("OutputFormat") ?? OutputFormat;
                OutputPath = configuration.GetObjectOrNull<string>("OutputPath") ?? OutputPath;
                OutputEncoding = configuration.GetObjectOrNull<string>("OutputEncoding") ?? OutputEncoding;
                Path = configuration.GetArrayOrNull<string>("Path") ?? Path;
                ExcludeTests = configuration.GetValueOrNull<bool>("ExcludeTests") ?? ExcludeTests;
            }
        }

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
                    _outputFormat = new StringOption(_outputFormat, value?.Value);
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
                    _outputPath = new StringOption(_outputPath, value?.Value);
                }
            }
        }

        public StringOption OutputEncoding
        {
            get { return _outputEncoding; }
            set
            {
                if (_outputEncoding == null)
                {
                    _outputEncoding = value;
                }
                else
                {
                    _outputEncoding = new StringOption(_outputEncoding, value?.Value);
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
                    _path = new StringArrayOption(_path, value?.Value);
                }
            }
        }

        public BoolOption ExcludeTests
        {
            get { return _excludeTests; }
            set
            {
                if (_excludeTests == null)
                {
                    _excludeTests = value;
                }
                else
                {
                    _excludeTests = new BoolOption(_excludeTests, value.Value);
                }
            }
        }
    }

    public class TestResultConfiguration : ConfigurationSection
    {
        private BoolOption _enabled;
        private StringOption _outputFormat;
        private StringOption _outputPath;
        private StringOption _testSuiteName;
        private StringOption _outputEncoding;

        public static TestResultConfiguration Default { get { return new TestResultConfiguration(); } }

        public static TestResultConfiguration ShallowClone(TestResultConfiguration configuration)
        {
            return Cloner.ShallowClone(configuration);
        }

        public TestResultConfiguration() : base("TestResult configuration.")
        {
            Enabled = new BoolOption("Enable TestResult.", false);
            OutputFormat = new StringOption("Format to use for test result report. Possible values: NUnitXml, NUnit2.5 or JUnitXml", "NUnitXml");
            OutputPath = new StringOption("Path relative to the current directory where test result report is saved.", "testResults.xml");
            OutputEncoding = new StringOption("Encoding of the output file.", "UTF8");
            TestSuiteName = new StringOption("Set the name assigned to the root 'test-suite' element.", "Pester");
        }

        public TestResultConfiguration(IDictionary configuration) : this()
        {
            if (configuration != null)
            {
                Enabled = configuration.GetValueOrNull<bool>("Enabled") ?? Enabled;
                OutputFormat = configuration.GetObjectOrNull<string>("OutputFormat") ?? OutputFormat;
                OutputPath = configuration.GetObjectOrNull<string>("OutputPath") ?? OutputPath;
                OutputEncoding = configuration.GetObjectOrNull<string>("OutputEncoding") ?? OutputPath;
                TestSuiteName = configuration.GetObjectOrNull<string>("TestSuiteName") ?? TestSuiteName;
            }
        }

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
                    _outputFormat = new StringOption(_outputFormat, value?.Value);
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
                    _outputPath = new StringOption(_outputPath, value?.Value);
                }
            }
        }

        public StringOption OutputEncoding
        {
            get { return _outputEncoding; }
            set
            {
                if (_outputEncoding == null)
                {
                    _outputEncoding = value;
                }
                else
                {
                    _outputEncoding = new StringOption(_outputEncoding, value?.Value);
                }
            }
        }

        public StringOption TestSuiteName
        {
            get { return _testSuiteName; }
            set
            {
                if (_testSuiteName == null)
                {
                    _testSuiteName = value;
                }
                else
                {
                    _testSuiteName = new StringOption(_testSuiteName, value?.Value);
                }
            }
        }
    }

    public class RunConfiguration : ConfigurationSection
    {
        private StringArrayOption _path;
        private StringArrayOption _excludePath;
        private ScriptBlockArrayOption _scriptBlock;
        private ContainerInfoArrayOption _container;
        private StringOption _testExtension;
        private BoolOption _exit;
        private BoolOption _passThru;

        public static RunConfiguration Default { get { return new RunConfiguration(); } }
        public static RunConfiguration ShallowClone(RunConfiguration configuration)
        {
            return Cloner.ShallowClone(configuration);
        }

        public RunConfiguration(IDictionary configuration) : this()
        {
            if (configuration != null)
            {
                Path = configuration.GetArrayOrNull<string>("Path") ?? Path;
                ExcludePath = configuration.GetArrayOrNull<string>("ExcludePath") ?? ExcludePath;
                ScriptBlock = configuration.GetArrayOrNull<ScriptBlock>("ScriptBlock") ?? ScriptBlock;
                Container = configuration.GetArrayOrNull<ContainerInfo>("Container") ?? Container;
                TestExtension = configuration.GetObjectOrNull<string>("TestExtension") ?? TestExtension;
                Exit = configuration.GetValueOrNull<bool>("Exit") ?? Exit;
                PassThru = configuration.GetValueOrNull<bool>("PassThru") ?? PassThru;
            }
        }

        public RunConfiguration() : base("Run configuration.")
        {
            Path = new StringArrayOption("Directories to be searched for tests, paths directly to test files, or combination of both.", new string[] { "." });
            ExcludePath = new StringArrayOption("Directories or files to be excluded from the run.", new string[0]);
            ScriptBlock = new ScriptBlockArrayOption("ScriptBlocks containing tests to be executed.", new ScriptBlock[0]);
            Container = new ContainerInfoArrayOption("ContainerInfo objects containing tests to be executed.", new ContainerInfo[0]);
            TestExtension = new StringOption("Filter used to identify test files.", ".Tests.ps1");
            Exit = new BoolOption("Exit with non-zero exit code when the test run fails.", false);
            PassThru = new BoolOption("Return result object to the pipeline after finishing the test run.", false);
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
                    _path = new StringArrayOption(_path, value?.Value);
                }
            }
        }

        public StringArrayOption ExcludePath
        {
            get { return _excludePath; }
            set
            {
                if (_excludePath == null)
                {
                    _excludePath = value;
                }
                else
                {
                    _excludePath = new StringArrayOption(_excludePath, value?.Value);
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
                    _scriptBlock = new ScriptBlockArrayOption(_scriptBlock, value?.Value);
                }
            }
        }

        public ContainerInfoArrayOption Container
        {
            get { return _container; }
            set
            {
                if (_container == null)
                {
                    _container = value;
                }
                else
                {
                    _container = new ContainerInfoArrayOption(_container, value?.Value);
                }
            }
        }

        public StringOption TestExtension
        {
            get { return _testExtension; }
            set
            {
                if (_testExtension == null)
                {
                    _testExtension = value;
                }
                else
                {
                    _testExtension = new StringOption(_testExtension, value?.Value);
                }
            }
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

        public BoolOption PassThru
        {
            get { return _passThru; }
            set
            {
                if (_passThru == null)
                {
                    _passThru = value;
                }
                else
                {
                    _passThru = new BoolOption(_passThru, value.Value);
                }
            }
        }
    }

    public class FilterConfiguration : ConfigurationSection
    {
        private StringArrayOption _tag;
        private StringArrayOption _excludeTag;
        private StringArrayOption _line;
        private StringArrayOption _fullName;

        public static FilterConfiguration Default { get { return new FilterConfiguration(); } }
        public static FilterConfiguration ShallowClone(FilterConfiguration configuration)
        {
            return Cloner.ShallowClone(configuration);
        }

        public FilterConfiguration(IDictionary configuration) : this()
        {
            if (configuration != null)
            {
                Tag = configuration.GetArrayOrNull<string>("Tag") ?? Tag;
                ExcludeTag = configuration.GetArrayOrNull<string>("ExcludeTag") ?? ExcludeTag;
                Line = configuration.GetArrayOrNull<string>("Line") ?? Line;
                FullName = configuration.GetArrayOrNull<string>("FullName") ?? FullName;
            }
        }
        public FilterConfiguration() : base("Filter configuration")
        {
            Tag = new StringArrayOption("Tags of Describe, Context or It to be run.", new string[0]);
            ExcludeTag = new StringArrayOption("Tags of Describe, Context or It to be excluded from the run.", new string[0]);
            Line = new StringArrayOption(@"Filter by file and scriptblock start line, useful to run parsed tests programatically to avoid problems with expanded names. Example: 'C:\tests\file1.Tests.ps1:37'", new string[0]);
            FullName = new StringArrayOption("Full name of test with -like wildcards, joined by dot. Example: '*.describe Get-Item.test1'", new string[0]);
        }

        public StringArrayOption Tag
        {
            get { return _tag; }
            set
            {
                if (_tag == null)
                {
                    _tag = value;
                }
                else
                {
                    _tag = new StringArrayOption(_tag, value?.Value);
                }
            }
        }

        public StringArrayOption ExcludeTag
        {
            get { return _excludeTag; }
            set
            {
                if (_excludeTag == null)
                {
                    _excludeTag = value;
                }
                else
                {
                    _excludeTag = new StringArrayOption(_excludeTag, value?.Value);
                }
            }
        }
        public StringArrayOption Line
        {
            get { return _line; }
            set
            {
                if (_line == null)
                {
                    _line = value;
                }
                else
                {
                    _line = new StringArrayOption(_line, value?.Value);
                }
            }
        }

        public StringArrayOption FullName
        {
            get { return _fullName; }
            set
            {
                if (_fullName == null)
                {
                    _fullName = value;
                }
                else
                {
                    _fullName = new StringArrayOption(_fullName, value?.Value);
                }
            }
        }
    }

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

public class PesterConfiguration
{
    public static PesterConfiguration Default { get { return new PesterConfiguration(); } }

    public static PesterConfiguration ShallowClone(PesterConfiguration configuration)
    {
        var cfg = Default;
        cfg.Run = RunConfiguration.ShallowClone(configuration.Run);
        cfg.Filter = FilterConfiguration.ShallowClone(configuration.Filter);
        cfg.CodeCoverage = CodeCoverageConfiguration.ShallowClone(configuration.CodeCoverage);
        cfg.TestResult = TestResultConfiguration.ShallowClone(configuration.TestResult);
        cfg.Should = ShouldConfiguration.ShallowClone(configuration.Should);
        cfg.Debug = DebugConfiguration.ShallowClone(configuration.Debug);
        cfg.Output = OutputConfiguration.ShallowClone(configuration.Output);
        return cfg;
    }

    public static PesterConfiguration Merge(PesterConfiguration configuration, PesterConfiguration @override)
    {
        var cfg = Default;
        cfg.Run = Merger.Merge(configuration.Run, @override.Run);
        cfg.Filter = Merger.Merge(configuration.Filter, @override.Filter);
        cfg.CodeCoverage = Merger.Merge(configuration.CodeCoverage, @override.CodeCoverage);
        cfg.TestResult = Merger.Merge(configuration.TestResult, @override.TestResult);
        cfg.Should = Merger.Merge(configuration.Should, @override.Should);
        cfg.Debug = Merger.Merge(configuration.Debug, @override.Debug);
        cfg.Output = Merger.Merge(configuration.Output, @override.Output);
        return cfg;
    }

    public PesterConfiguration(IDictionary configuration)
    {
        if (configuration != null)
        {
            Run = new RunConfiguration(configuration.GetIDictionaryOrNull("Run"));
            Filter = new FilterConfiguration(configuration.GetIDictionaryOrNull("Filter"));
            CodeCoverage = new CodeCoverageConfiguration(configuration.GetIDictionaryOrNull("CodeCoverage"));
            TestResult = new TestResultConfiguration(configuration.GetIDictionaryOrNull("TestResult"));
            Should = new ShouldConfiguration(configuration.GetIDictionaryOrNull("Should"));
            Debug = new DebugConfiguration(configuration.GetIDictionaryOrNull("Debug"));
            Output = new OutputConfiguration(configuration.GetIDictionaryOrNull("Output"));
        }
    }

    public PesterConfiguration()
    {
        Run = new RunConfiguration();
        Filter = new FilterConfiguration();
        CodeCoverage = new CodeCoverageConfiguration();
        TestResult = new TestResultConfiguration();
        Should = new ShouldConfiguration();
        Debug = new DebugConfiguration();
        Output = new OutputConfiguration();
    }

    public RunConfiguration Run { get; set; }
    public FilterConfiguration Filter { get; set; }
    public CodeCoverageConfiguration CodeCoverage { get; set; }
    public TestResultConfiguration TestResult { get; set; }
    public ShouldConfiguration Should { get; set; }
    public DebugConfiguration Debug { get; set; }
    public OutputConfiguration Output { get; set; }
}
