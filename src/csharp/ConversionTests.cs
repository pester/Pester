using System;
using System.Collections.Generic;
using System.Text;
using Xunit;

namespace Pester
{
    public class ConversionTests
    {
        [Fact]
        public void ScriptBlockToScriptArrayOptionConversion()
        {

        }

        [Fact]
        public void Clone()
        {
            var d = PesterConfiguration.Default;
            var c = PesterConfiguration.ShallowClone(d);
        }
    }
}
