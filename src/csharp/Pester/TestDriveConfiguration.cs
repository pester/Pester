using System.Collections;

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
        public TestDriveConfiguration() : base("Options to configure the TestDrive feature.")
        {
            Enabled = new BoolOption("Enable TestDrive.", true);
        }

        public TestDriveConfiguration(IDictionary configuration) : this()
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
