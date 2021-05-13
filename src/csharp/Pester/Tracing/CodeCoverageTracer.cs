using System.Collections.Generic;
using System.Management.Automation;
using System.Management.Automation.Language;

namespace Pester.Tracing
{
    public class CodeCoverageTracer : ITracer
    {
        public static CodeCoverageTracer Create(List<CodeCoveragePoint> points)
        {
            return new CodeCoverageTracer(points);
        }

        public CodeCoverageTracer(List<CodeCoveragePoint> points)
        {
            foreach (var point in points)
            {
                var key = $"{point.Line}:{point.Column}";
                if (!Hits.ContainsKey(point.Path))
                {
                    var lineColumn = new Dictionary<string, CodeCoveragePoint> { [key] = point };
                    Hits.Add(point.Path, lineColumn);
                    continue;
                }

                var hits = Hits[point.Path];
                if (!hits.ContainsKey(key))
                {
                    hits.Add(key, point);
                    continue;
                }

                // if the key is there do nothing, we already set it to false
            }
        }

        // list of what Pester figures out from the AST that we care about for CC
        // keyed as path -> line:column -> CodeCoveragePoint
        public Dictionary<string, Dictionary<string, CodeCoveragePoint>> Hits { get; } = new Dictionary<string, Dictionary<string, CodeCoveragePoint>>();

        public void Trace(IScriptExtent extent, ScriptBlock _, int __)
        {
            // ignore unbound scriptblocks
            if (extent?.File == null)
                return;

            // Console.WriteLine($"{extent.File}:{extent.StartLineNumber}:{extent.StartColumnNumber}:{extent.Text}");
            if (!Hits.TryGetValue(extent.File, out var lineColumn))
                return;

            var key2 = $"{extent.StartLineNumber}:{extent.StartColumnNumber}";
            if (!lineColumn.ContainsKey(key2))
                return;


            var point = lineColumn[key2];
            if (point.Hit == true)
                return;

            point.Hit = true;
            point.Text = extent.Text;

            lineColumn[key2] = point;
        }
    }
}
