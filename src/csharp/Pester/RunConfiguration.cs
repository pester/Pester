using System.Collections;
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
    public class RunConfiguration : ConfigurationSection
    {
        private StringArrayOption _path;
        private StringArrayOption _excludePath;
        private ScriptBlockArrayOption _scriptBlock;
        private ContainerInfoArrayOption _container;
        private StringOption _testExtension;
        private BoolOption _exit;
        private BoolOption _throw;
        private BoolOption _passThru;
        private BoolOption _skipRun;
        private StringOption _skipRemainingOnFailure;
        private BoolOption _failOnNullOrEmptyForEach;

        public static RunConfiguration Default { get { return new RunConfiguration(); } }
        public static RunConfiguration ShallowClone(RunConfiguration configuration)
        {
            return Cloner.ShallowClone(configuration);
        }

        public RunConfiguration(IDictionary configuration) : this()
        {
            if (configuration != null)
            {
                configuration.AssignArrayIfNotNull<string>(nameof(Path), v => Path = v);
                configuration.AssignArrayIfNotNull<string>(nameof(ExcludePath), v => ExcludePath = v);
                configuration.AssignArrayIfNotNull<ScriptBlock>(nameof(ScriptBlock), v => ScriptBlock = v);
                configuration.AssignArrayIfNotNull<ContainerInfo>(nameof(Container), v => Container = v);
                configuration.AssignObjectIfNotNull<string>(nameof(TestExtension), v => TestExtension = v);
                configuration.AssignValueIfNotNull<bool>(nameof(Exit), v => Exit = v);
                configuration.AssignValueIfNotNull<bool>(nameof(Throw), v => Throw = v);
                configuration.AssignValueIfNotNull<bool>(nameof(PassThru), v => PassThru = v);
                configuration.AssignValueIfNotNull<bool>(nameof(SkipRun), v => SkipRun = v);
                configuration.AssignObjectIfNotNull<string>(nameof(SkipRemainingOnFailure), v => SkipRemainingOnFailure = v);
                configuration.AssignValueIfNotNull<bool>(nameof(FailOnNullOrEmptyForEach ), v => FailOnNullOrEmptyForEach  = v);
            }
        }

        public RunConfiguration() : base("General runtime options for Pester including tests containers to execute.")
        {
            Path = new StringArrayOption("Directories to be searched for tests, paths directly to test files, or combination of both.", new string[] { "." });
            ExcludePath = new StringArrayOption("Directories or files to be excluded from the run.", new string[0]);
            ScriptBlock = new ScriptBlockArrayOption("ScriptBlocks containing tests to be executed.", new ScriptBlock[0]);
            Container = new ContainerInfoArrayOption("ContainerInfo objects containing tests to be executed.", new ContainerInfo[0]);
            TestExtension = new StringOption("Filter used to identify test files.", ".Tests.ps1");
            Exit = new BoolOption("Exit with non-zero exit code when the test run fails. Exit code is always set to `$LASTEXITCODE` even when this option is `$false`. When used together with Throw, throwing an exception is preferred.", false);
            Throw = new BoolOption("Throw an exception when test run fails. When used together with Exit, throwing an exception is preferred.", false);
            PassThru = new BoolOption("Return result object to the pipeline after finishing the test run.", false);
            SkipRun = new BoolOption("Runs the discovery phase but skips run. Use it with PassThru to get object populated with all tests.", false);
            SkipRemainingOnFailure = new StringOption("Skips remaining tests after failure for selected scope, options are None, Run, Container and Block.", "None");
            FailOnNullOrEmptyForEach  = new BoolOption("Fails discovery when -ForEach is provided $null or @() in a block or test. Can be overriden for a specific Describe/Context/It using -AllowNullOrEmptyForEach.", true);
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

        public BoolOption Throw
        {
            get { return _throw; }
            set
            {
                if (_throw == null)
                {
                    _throw = value;
                }
                else
                {
                    _throw = new BoolOption(_throw, value.Value);
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

        public BoolOption SkipRun
        {
            get { return _skipRun; }
            set
            {
                if (_skipRun == null)
                {
                    _skipRun = value;
                }
                else
                {
                    _skipRun = new BoolOption(_skipRun, value.Value);
                }
            }
        }

        public StringOption SkipRemainingOnFailure
        {
            get { return _skipRemainingOnFailure; }
            set
            {
                if (_skipRemainingOnFailure == null)
                {
                    _skipRemainingOnFailure = value;
                }
                else
                {
                    _skipRemainingOnFailure = new StringOption(_skipRemainingOnFailure, value?.Value);
                }
            }
        }

        public BoolOption FailOnNullOrEmptyForEach
        {
            get { return _failOnNullOrEmptyForEach; }
            set
            {
                if (_failOnNullOrEmptyForEach == null)
                {
                    _failOnNullOrEmptyForEach = value;
                }
                else
                {
                    _failOnNullOrEmptyForEach = new BoolOption(_failOnNullOrEmptyForEach, value.Value);
                }
            }
        }
    }
}
