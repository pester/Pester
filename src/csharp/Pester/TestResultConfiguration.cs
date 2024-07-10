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

        public TestResultConfiguration() : base("Export options to output Pester's testresult to knwon file formats like NUnit and JUnit XML.")
        {
            Enabled = new BoolOption("Enable TestResult.", false);
            OutputFormat = new StringOption("Format to use for test result report. Possible values: NUnitXml, NUnit2.5, NUnit3 or JUnitXml", "NUnitXml");
            OutputPath = new StringOption("Path relative to the current directory where test result report is saved.", "testResults.xml");
            OutputEncoding = new StringOption("Encoding of the output file.", "UTF8");
            TestSuiteName = new StringOption("Set the name assigned to the root 'test-suite' element.", "Pester");
        }

        public TestResultConfiguration(IDictionary configuration) : this()
        {
            if (configuration != null)
            {
                configuration.AssignValueIfNotNull<bool>(nameof(Enabled), v => Enabled = v);
                configuration.AssignObjectIfNotNull<string>(nameof(OutputFormat), v => OutputFormat = v);
                configuration.AssignObjectIfNotNull<string>(nameof(OutputPath), v => OutputPath = v);
                configuration.AssignObjectIfNotNull<string>(nameof(OutputEncoding), v => OutputEncoding = v);
                configuration.AssignObjectIfNotNull<string>(nameof(TestSuiteName), v => TestSuiteName = v);
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
}
