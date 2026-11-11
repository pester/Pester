using System;

namespace Pester
{
    /// <summary>
    /// Thrown when a configuration key holds a value the option cannot use, for example a string
    /// where a bool is expected. Its own type so PesterConfiguration can recognize it while
    /// building the sections and prefix the message with the section name.
    /// </summary>
    public class ConfigurationValueException : ArgumentException
    {
        public ConfigurationValueException(string message) : base(message) { }
    }
}
