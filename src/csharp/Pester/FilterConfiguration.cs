﻿using System.Collections;

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
}
