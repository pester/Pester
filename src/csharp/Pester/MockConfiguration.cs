using System.Collections;

namespace Pester
{
    public class MockConfiguration : ConfigurationSection
    {
        private BoolOption _global;

        public static MockConfiguration Default { get { return new MockConfiguration(); } }

        public static MockConfiguration ShallowClone(MockConfiguration configuration)
        {
            return Cloner.ShallowClone(configuration);
        }

        public MockConfiguration() : base("Mock configuration for Pester.")
        {
            Global = new BoolOption("EXPERIMENTAL: Make every mock a global mock, so it is applied to calls from any module or script, and the ModuleName parameter is ignored. This is the same as passing -Global to every Mock. Use at your own risk!", false);
        }

        public MockConfiguration(IDictionary configuration) : this()
        {
            configuration?.AssignValueIfNotNull<bool>(nameof(Global), v => Global = v);
        }

        public BoolOption Global
        {
            get { return _global; }
            set
            {
                if (_global == null)
                {
                    _global = value;
                }
                else
                {
                    _global = new BoolOption(_global, value.Value);
                }
            }
        }
    }
}
