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
    public class CodeCoverageConfiguration : ConfigurationSection
    {
        private BoolOption _enabled;
        private StringOption _outputFormat;
        private StringOption _outputPath;
        private StringOption _outputEncoding;
        private StringArrayOption _path;
        private BoolOption _excludeTests;
        private BoolOption _recursePaths;
        private BoolOption _useBps;
        private BoolOption _singleHitBreakpoints;
        private DecimalOption _coveragePercentTarget;

        public static CodeCoverageConfiguration Default { get { return new CodeCoverageConfiguration(); } }

        public static CodeCoverageConfiguration ShallowClone(CodeCoverageConfiguration configuration)
        {
            return Cloner.ShallowClone(configuration);
        }
        public CodeCoverageConfiguration() : base("Options to enable and configure Pester's code coverage feature.")
        {
            Enabled = new BoolOption("Enable CodeCoverage.", false);
            OutputFormat = new StringOption("Format to use for code coverage report. Possible values: JaCoCo, CoverageGutters, Cobertura", "JaCoCo");
            OutputPath = new StringOption("Path relative to the current directory where code coverage report is saved.", "coverage.xml");
            OutputEncoding = new StringOption("Encoding of the output file.", "UTF8");
            Path = new StringArrayOption("Directories or files to be used for code coverage, by default the Path(s) from general settings are used, unless overridden here.", new string[0]);
            ExcludeTests = new BoolOption("Exclude tests from code coverage. This uses the TestFilter from general configuration.", true);
            RecursePaths = new BoolOption("Will recurse through directories in the Path option.", true);
            UseBreakpoints = new BoolOption("When false, use Profiler based tracer to do CodeCoverage instead of using breakpoints.", false);
            CoveragePercentTarget = new DecimalOption("Target percent of code coverage that you want to achieve, default 75%.", 75m);
            SingleHitBreakpoints = new BoolOption("Remove breakpoint when it is hit. This increases performance of breakpoint based CodeCoverage.", true);
        }

        public CodeCoverageConfiguration(IDictionary configuration) : this()
        {
            if (configuration != null)
            {
                configuration.AssignValueIfNotNull<bool>(nameof(Enabled), v => Enabled = v);
                configuration.AssignObjectIfNotNull<string>(nameof(OutputFormat), v => OutputFormat = v);
                configuration.AssignObjectIfNotNull<string>(nameof(OutputPath), v => OutputPath = v);
                configuration.AssignObjectIfNotNull<string>(nameof(OutputEncoding), v => OutputEncoding = v);
                configuration.AssignArrayIfNotNull<string>(nameof(Path), v => Path = v);
                configuration.AssignValueIfNotNull<bool>(nameof(ExcludeTests), v => ExcludeTests = v);
                configuration.AssignValueIfNotNull<bool>(nameof(RecursePaths), v => RecursePaths = v);
                configuration.AssignValueIfNotNull<bool>(nameof(UseBreakpoints), v => UseBreakpoints = v);
                configuration.AssignValueIfNotNull<decimal>(nameof(CoveragePercentTarget), v => CoveragePercentTarget = v);
                configuration.AssignValueIfNotNull<bool>(nameof(SingleHitBreakpoints), v => SingleHitBreakpoints = v);
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

        public BoolOption RecursePaths
        {
            get { return _recursePaths; }
            set
            {
                if (_recursePaths == null)
                {
                    _recursePaths = value;
                }
                else
                {
                    _recursePaths = new BoolOption(_recursePaths, value.Value);
                }
            }
        }

        public DecimalOption CoveragePercentTarget
        {
            get { return _coveragePercentTarget; }
            set
            {
                if (_coveragePercentTarget == null)
                {
                    _coveragePercentTarget = value;
                }
                else
                {
                    _coveragePercentTarget = new DecimalOption(_coveragePercentTarget, value.Value);
                }
            }
        }

        public BoolOption UseBreakpoints
        {
            get { return _useBps; }
            set
            {
                if (_useBps == null)
                {
                    _useBps = value;
                }
                else
                {
                    _useBps = new BoolOption(_useBps, value.Value);
                }
            }
        }

        public BoolOption SingleHitBreakpoints
        {
            get { return _singleHitBreakpoints; }
            set
            {
                if (_singleHitBreakpoints == null)
                {
                    _singleHitBreakpoints = value;
                }
                else
                {
                    _singleHitBreakpoints = new BoolOption(_singleHitBreakpoints, value.Value);
                }
            }
        }
    }
}
