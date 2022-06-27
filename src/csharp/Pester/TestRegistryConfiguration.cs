using System.Collections;

namespace Pester
{
    public class TestRegistryConfiguration : ConfigurationSection
    {
        private BoolOption _enabled;

        public static TestRegistryConfiguration Default { get { return new TestRegistryConfiguration(); } }

        public static TestRegistryConfiguration ShallowClone(TestRegistryConfiguration configuration)
        {
            return Cloner.ShallowClone(configuration);
        }
        public TestRegistryConfiguration() : base("TestRegistry configuration.")
        {
            Enabled = new BoolOption("Enable TestRegistry.", true);
        }

        public TestRegistryConfiguration(IDictionary configuration) : this()
        {
            if (configuration != null)
            {
                if (configuration.GetValueOrNull<bool>(nameof(Enabled)) is bool enabled) { Enabled = enabled; };
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
