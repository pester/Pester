using System.Collections.Generic;
using System.Management.Automation;

namespace Pester
{
    /// <summary>
    /// A list of script blocks that renders as its contents rather than as its type name.
    ///
    /// A block can hold more than one BeforeAll (and each of the other setups and teardowns) since
    /// the folder-level Pester.BeforeContainer.ps1 setup composes with the test file's own. Those
    /// properties used to be a single ScriptBlock, so anything doing $block.OneTimeTestSetup.ToString()
    /// would start getting "System.Collections.Generic.List`1[System.Management.Automation.ScriptBlock]"
    /// back. Rendering the contents instead keeps the common case, where there is exactly one, printing
    /// the same text it printed before.
    /// </summary>
    public class ScriptBlockCollection : List<ScriptBlock>
    {
        public ScriptBlockCollection() { }

        public ScriptBlockCollection(IEnumerable<ScriptBlock> collection) : base(collection) { }

        public override string ToString()
        {
            return ToStringConverter.ScriptBlockCollectionToString(this);
        }
    }
}
