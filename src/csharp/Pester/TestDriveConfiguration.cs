﻿using System.Collections;

namespace Pester
{
    public class TestDriveConfiguration : ConfigurationSection
    {
        private BoolOption _enabled;

        public static TestDriveConfiguration Default { get { return new TestDriveConfiguration(); } }

        public static TestDriveConfiguration ShallowClone(TestDriveConfiguration configuration)
        {
            return Cloner.ShallowClone(configuration);
        }
        public TestDriveConfiguration() : base("TestDrive configuration.")
        {
            Enabled = new BoolOption("Enable TestDrive.", true);
        }

        public TestDriveConfiguration(IDictionary configuration) : this()
        {
            if (configuration != null)
            {
                Enabled = configuration.GetValueOrNull<bool>(nameof(Enabled)) ?? Enabled;
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
    }
}
