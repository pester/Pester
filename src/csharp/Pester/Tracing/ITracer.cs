using System.Management.Automation;
using System.Management.Automation.Language;

namespace Pester.Tracing
{
    public interface ITracer
    {
        void Trace(IScriptExtent extent, ScriptBlock scriptBlock, int level);
    }
}
