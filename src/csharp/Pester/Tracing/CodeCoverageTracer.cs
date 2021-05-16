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
                    var lineColumn = new Dictionary<string, List<CodeCoveragePoint>> { [key] = new List<CodeCoveragePoint> { point } };
                    Hits.Add(point.Path, lineColumn);
                    continue;
                }

                var hits = Hits[point.Path];
                if (!hits.ContainsKey(key))
                {
                    hits.Add(key, new List<CodeCoveragePoint> { point });
                    continue;
                }
                else
                {
                    var pointsOnLineAndColumn = hits[key];
                    pointsOnLineAndColumn.Add(point);
                }

            }
        }

        // list of what Pester figures out from the AST that we care about for CC
        // keyed as path -> line:column -> CodeCoveragePoint
        public Dictionary<string, Dictionary<string, List<CodeCoveragePoint>>> Hits { get; } = new Dictionary<string, Dictionary<string, List<CodeCoveragePoint>>>();

        public void Trace(IScriptExtent extent, ScriptBlock sb, int level)
        {
            //if (!extent?.File?.Contains("pester") ?? false)
            //{
            //    System.Console.WriteLine($"ex: {extent.File}:{extent.StartLineNumber}:{extent.StartColumnNumber}:{extent.Text} l: {level}");
            //}

            // ignore unbound scriptblocks
            if (extent?.File == null)
                return;
            if (!Hits.TryGetValue(extent.File, out var lineColumn))
                return;

            var key2 = $"{extent.StartLineNumber}:{extent.StartColumnNumber}";
            if (!lineColumn.ContainsKey(key2))
                return;


            var points = lineColumn[key2];
            if (points.TrueForAll(a=>a.Hit))
            {
                return;
            }

            for(var i =0; i < points.Count; i++)
            {
                var point = points[i];
                point.Hit = true;
                point.Text = extent.Text;
                points[i] = point;
            }

            lineColumn[key2] = points;
        }
    }
}
