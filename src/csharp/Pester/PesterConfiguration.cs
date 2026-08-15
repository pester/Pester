using Pester;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Management.Automation;
using System.Reflection;

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

// PesterConfiguration type is on purpose outside of any namespace
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
        cfg.Mock = MockConfiguration.ShallowClone(configuration.Mock);
        cfg._unknownKeys = configuration._unknownKeys;
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
        cfg.Mock = Merger.Merge(configuration.Mock, @override.Mock);
        // Invoke-Pester merges onto the default configuration before it reports anything, so the
        // unknown keys have to survive the merge or the warning is lost.
        var unknown = new List<string>(configuration._unknownKeys);
        foreach (var key in @override._unknownKeys)
        {
            if (!unknown.Contains(key))
                unknown.Add(key);
        }
        cfg._unknownKeys = unknown.ToArray();
        return cfg;
    }

    public PesterConfiguration(IDictionary configuration)
    {
        if (configuration != null)
        {
            Run = Section(configuration, nameof(Run), d => new RunConfiguration(d));
            Filter = Section(configuration, nameof(Filter), d => new FilterConfiguration(d));
            CodeCoverage = Section(configuration, nameof(CodeCoverage), d => new CodeCoverageConfiguration(d));
            TestResult = Section(configuration, nameof(TestResult), d => new TestResultConfiguration(d));
            Should = Section(configuration, nameof(Should), d => new ShouldConfiguration(d));
            Debug = Section(configuration, nameof(Debug), d => new DebugConfiguration(d));
            Output = Section(configuration, nameof(Output), d => new OutputConfiguration(d));
            TestDrive = Section(configuration, nameof(TestDrive), d => new TestDriveConfiguration(d));
            TestRegistry = Section(configuration, nameof(TestRegistry), d => new TestRegistryConfiguration(d));
            Mock = Section(configuration, nameof(Mock), d => new MockConfiguration(d));

            _unknownKeys = CollectUnknownKeys(configuration);
        }
    }

    // Build one section, and put the section name in front of the message when the section rejects
    // a value, so the user is told 'Run.Parallel expects ...' and not just 'Parallel expects ...'.
    private static T Section<T>(IDictionary configuration, string name, Func<IDictionary, T> create)
        where T : ConfigurationSection
    {
        // Resolved outside the try, its own message already names the section.
        var options = configuration.GetIDictionaryOrNull(name);
        try
        {
            return create(options);
        }
        catch (ConfigurationValueException e)
        {
            throw new ConfigurationValueException($"{name}.{e.Message}");
        }
    }

    // Keys the configuration does not have an option for. They are collected rather than thrown on,
    // because a hashtable may legitimately be shared with something else, and reported by the caller
    // (Invoke-Pester warns) so a misspelled option does not quietly do nothing (#2975).
    private static string[] CollectUnknownKeys(IDictionary configuration)
    {
        var unknown = new List<string>();
        var sections = new PesterConfiguration();

        foreach (var key in configuration.Keys)
        {
            var name = key as string ?? key?.ToString();
            var property = Match(sections.GetType().GetProperties(BindingFlags.Public | BindingFlags.Instance), name, configuration);
            if (property == null)
            {
                unknown.Add(name);
                continue;
            }

            // A known section, so check the options inside it the same way.
            var section = property.GetValue(sections) as ConfigurationSection;
            var options = configuration[property.Name] as IDictionary
                ?? (configuration[property.Name] as PSObject)?.BaseObject as IDictionary;
            if (section == null || options == null)
                continue;

            var known = section.GetOptionNames();
            foreach (var optionKey in options.Keys)
            {
                var optionName = optionKey as string ?? optionKey?.ToString();
                if (Find(known, optionName, options) == null)
                    unknown.Add($"{property.Name}.{optionName}");
            }
        }

        return unknown.ToArray();
    }

    // A key counts as known only when looking it up by the option's own name finds it. Comparing
    // case-insensitively alone is not enough: a dictionary with a case-sensitive comparer holds
    // 'run' without answering to 'Run', so the value would never be read and the key is unknown.
    private static PropertyInfo Match(PropertyInfo[] properties, string name, IDictionary dictionary)
    {
        foreach (var property in properties)
        {
            if (!typeof(ConfigurationSection).IsAssignableFrom(property.PropertyType))
                continue;

            if (string.Equals(property.Name, name, StringComparison.OrdinalIgnoreCase) && dictionary.Contains(property.Name))
                return property;
        }

        return null;
    }

    private static string Find(string[] names, string name, IDictionary dictionary)
    {
        foreach (var known in names)
        {
            if (string.Equals(known, name, StringComparison.OrdinalIgnoreCase) && dictionary.Contains(known))
                return known;
        }

        return null;
    }

    private string[] _unknownKeys = new string[0];

    /// <summary>
    /// Keys found in the hashtable this configuration was built from that do not match any section
    /// or option. A method and not a property so it stays out of the configuration's console output.
    /// </summary>
    public string[] GetUnknownKeys()
    {
        return _unknownKeys;
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
        Mock = new MockConfiguration();
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
    public MockConfiguration Mock { get; set; }
}
