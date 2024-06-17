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
        public TestRegistryConfiguration() : base("Options to configure the TestRegistry feature. TestRegistry is only available on Windows-systems.")
        {
            Enabled = new BoolOption("Enable TestRegistry.", true);
        }

        public TestRegistryConfiguration(IDictionary configuration) : this()
        {
            configuration?.AssignValueIfNotNull<bool>(nameof(Enabled), v => Enabled = v);
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
