using Pester;
using System.Collections;
using System.Diagnostics.CodeAnalysis;
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

[SuppressMessage("Design", "RCS1110", Justification = "PesterConfiguration type is outside of any namespace on purpose")]
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
        cfg.TestDrive = TestDriveConfiguration.ShallowClone(configuration.TestDrive);
        cfg.TestRegistry = TestRegistryConfiguration.ShallowClone(configuration.TestRegistry);
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
        cfg.TestDrive = Merger.Merge(configuration.TestDrive, @override.TestDrive);
        cfg.TestRegistry = Merger.Merge(configuration.TestRegistry, @override.TestRegistry);
        return cfg;
    }

    public PesterConfiguration(IDictionary configuration)
    {
        if (configuration != null)
        {
            Run = new RunConfiguration(configuration.GetIDictionaryOrNull(nameof(Run)));
            Filter = new FilterConfiguration(configuration.GetIDictionaryOrNull(nameof(Filter)));
            CodeCoverage = new CodeCoverageConfiguration(configuration.GetIDictionaryOrNull(nameof(CodeCoverage)));
            TestResult = new TestResultConfiguration(configuration.GetIDictionaryOrNull(nameof(TestResult)));
            Should = new ShouldConfiguration(configuration.GetIDictionaryOrNull(nameof(Should)));
            Debug = new DebugConfiguration(configuration.GetIDictionaryOrNull(nameof(Debug)));
            Output = new OutputConfiguration(configuration.GetIDictionaryOrNull(nameof(Output)));
            TestDrive = new TestDriveConfiguration(configuration.GetIDictionaryOrNull(nameof(TestDrive)));
            TestRegistry = new TestRegistryConfiguration(configuration.GetIDictionaryOrNull(nameof(TestRegistry)));
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
        TestDrive = new TestDriveConfiguration();
        TestRegistry = new TestRegistryConfiguration();
    }

    public RunConfiguration Run { get; set; }
    public FilterConfiguration Filter { get; set; }
    public CodeCoverageConfiguration CodeCoverage { get; set; }
    public TestResultConfiguration TestResult { get; set; }
    public ShouldConfiguration Should { get; set; }
    public DebugConfiguration Debug { get; set; }
    public OutputConfiguration Output { get; set; }
    public TestDriveConfiguration TestDrive { get; set; }
    public TestRegistryConfiguration TestRegistry { get; set; }
}
