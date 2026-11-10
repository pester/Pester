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
        return cfg;
    }

    public PesterConfiguration(IDictionary configuration)
    {
        if (configuration != null)
        {
            // Every problem the configuration has, not only the first one. Fixing one, rerunning and
            // finding the next is a bad loop to be in, and a key the configuration has no option for
            // used to only warn, which scrolls past in CI and leaves the run on the default (#3058).
            var problems = new List<string>();

            foreach (var problem in DescribeUnknownKeys(configuration))
                problems.Add(problem);

            Run = Section(configuration, nameof(Run), d => new RunConfiguration(d), problems);
            Filter = Section(configuration, nameof(Filter), d => new FilterConfiguration(d), problems);
            CodeCoverage = Section(configuration, nameof(CodeCoverage), d => new CodeCoverageConfiguration(d), problems);
            TestResult = Section(configuration, nameof(TestResult), d => new TestResultConfiguration(d), problems);
            Should = Section(configuration, nameof(Should), d => new ShouldConfiguration(d), problems);
            Debug = Section(configuration, nameof(Debug), d => new DebugConfiguration(d), problems);
            Output = Section(configuration, nameof(Output), d => new OutputConfiguration(d), problems);
            TestDrive = Section(configuration, nameof(TestDrive), d => new TestDriveConfiguration(d), problems);
            TestRegistry = Section(configuration, nameof(TestRegistry), d => new TestRegistryConfiguration(d), problems);
            Mock = Section(configuration, nameof(Mock), d => new MockConfiguration(d), problems);

            if (problems.Count > 0)
                throw new ConfigurationValueException(FormatProblems(problems));
        }
    }

    // One problem reads as the sentence it is; several are worth a list, with a count so it is clear
    // up front how much there is to fix.
    private static string FormatProblems(List<string> problems)
    {
        var message = problems.Count == 1
            ? problems[0]
            : $"The configuration has {problems.Count} problems:{Environment.NewLine}  - " + string.Join($"{Environment.NewLine}  - ", problems.ToArray());

        foreach (var problem in problems)
        {
            if (problem.Contains("no such option") || problem.Contains("no such section"))
                return message + $"{Environment.NewLine}'Get-Help about_PesterConfiguration' lists all the options.";
        }

        return message;
    }

    // Build one section, collecting what it cannot use instead of throwing on it, and put the
    // section name in front of each problem, so the user is told 'Run.Parallel expects ...' and not
    // just 'Parallel expects ...'.
    private static T Section<T>(IDictionary configuration, string name, Func<IDictionary, T> create, List<string> problems)
        where T : ConfigurationSection
    {
        // The section itself, whose own message already names it, so no prefix for this one.
        IDictionary options;
        var sectionProblems = new List<string>();
        using (DictionaryExtensions.CollectProblems(sectionProblems))
        {
            options = configuration.GetIDictionaryOrNull(name);
        }

        if (sectionProblems.Count > 0)
        {
            problems.AddRange(sectionProblems);
            return create(null);
        }

        var optionProblems = new List<string>();
        try
        {
            T section;
            using (DictionaryExtensions.CollectProblems(optionProblems))
            {
                section = create(options);
            }

            foreach (var problem in optionProblems)
                problems.Add($"{name}.{problem}");

            return section;
        }
        catch (ConfigurationValueException e)
        {
            // A section that rejects a value some other way than through the collector.
            foreach (var problem in optionProblems)
                problems.Add($"{name}.{problem}");
            problems.Add($"{name}.{e.Message}");
            return create(null);
        }
    }

    // Keys the configuration has no section or option for. It is a configuration hashtable, so there
    // is nothing else it should be carrying, and a key that matches nothing is a mistake: #2975 only
    // warned about it, which scrolls past in CI and leaves the run on the default (#3058).
    //
    // Sorted, because they are found by walking a hashtable and a hashtable does not enumerate in a
    // stable order. .NET randomizes string hashing per process, so without this the same
    // configuration would list its problems differently from one run to the next.
    private static List<string> DescribeUnknownKeys(IDictionary configuration)
    {
        var problems = new List<string>();
        var sections = new PesterConfiguration();
        var sectionProperties = sections.GetType().GetProperties(BindingFlags.Public | BindingFlags.Instance);

        var sectionNames = new List<string>();
        foreach (var property in sectionProperties)
        {
            if (typeof(ConfigurationSection).IsAssignableFrom(property.PropertyType))
                sectionNames.Add(property.Name);
        }

        foreach (var key in configuration.Keys)
        {
            var name = key as string ?? key?.ToString();
            var property = Match(sectionProperties, name, configuration);
            if (property == null)
            {
                problems.Add($"{name}: no such section{Suggest(name, sectionNames, null)}");
                continue;
            }

            // A known section, so check the options inside it the same way.
            var section = property.GetValue(sections) as ConfigurationSection;
            var options = configuration[property.Name] as IDictionary
                ?? (configuration[property.Name] as PSObject)?.BaseObject as IDictionary;
            if (section == null || options == null)
                continue;

            var known = new List<string>(section.GetOptionNames());
            foreach (var optionKey in options.Keys)
            {
                var optionName = optionKey as string ?? optionKey?.ToString();
                if (Find(known.ToArray(), optionName, options) == null)
                    problems.Add($"{property.Name}.{optionName}: no such option{Suggest(optionName, known, property.Name)}");
            }
        }

        problems.Sort(StringComparer.OrdinalIgnoreCase);
        return problems;
    }

    // ', did you mean 'Run.Parallel'?' when one of the known names is close enough to be a typo of
    // what was written, and just '.' when none is. 'Paralel' is one edit from 'Parallel', so saying
    // so turns rereading the documentation into fixing one letter.
    private static string Suggest(string name, List<string> known, string prefix)
    {
        if (string.IsNullOrEmpty(name))
            return ".";

        var best = (string)null;
        var bestDistance = int.MaxValue;
        foreach (var candidate in known)
        {
            var distance = Distance(name, candidate);
            if (distance < bestDistance)
            {
                bestDistance = distance;
                best = candidate;
            }
        }

        // One edit per four characters, so a short name does not match everything and a long one is
        // still allowed a slip or two.
        var allowed = Math.Max(2, name.Length / 4);
        if (best == null || bestDistance > allowed)
            return ".";

        var suggestion = prefix == null ? best : $"{prefix}.{best}";
        return $", did you mean '{suggestion}'?";
    }

    // Levenshtein distance, case-insensitive. The names are short, so the straightforward table is
    // as fast as anything cleverer.
    private static int Distance(string a, string b)
    {
        a = a.ToLowerInvariant();
        b = b.ToLowerInvariant();

        var previous = new int[b.Length + 1];
        var current = new int[b.Length + 1];
        for (var j = 0; j <= b.Length; j++)
            previous[j] = j;

        for (var i = 1; i <= a.Length; i++)
        {
            current[0] = i;
            for (var j = 1; j <= b.Length; j++)
            {
                var substitute = previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1);
                current[j] = Math.Min(Math.Min(current[j - 1] + 1, previous[j] + 1), substitute);
            }

            var swap = previous;
            previous = current;
            current = swap;
        }

        return previous[b.Length];
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
