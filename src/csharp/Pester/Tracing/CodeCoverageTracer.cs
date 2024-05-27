using System;
using System.Collections.Generic;
using System.Globalization;
using System.Management.Automation;
using System.Management.Automation.Language;

namespace Pester.Tracing
{
    public class CodeCoverageTracer : ITracer
    {
        private readonly bool _debug;
        private readonly string _debugFile;

        public static CodeCoverageTracer Create(List<CodeCoveragePoint> points)
        {
            return new CodeCoverageTracer(points);
        }

        public CodeCoverageTracer(List<CodeCoveragePoint> points)
        {
            _debug = Environment.GetEnvironmentVariable("PESTER_CC_DEBUG") == "1";
            _debugFile = Environment.GetEnvironmentVariable("PESTER_CC_DEBUG_FILE") ?? "CoverageTestFile";
            foreach (var point in points)
            {
                var key = $"{point.Line}:{point.Column}";
                if (!Hits.ContainsKey(point.Path))
                {
                    var lineColumn = new Dictionary<string, List<CodeCoveragePoint>> (StringComparer.OrdinalIgnoreCase) { [key] = new List<CodeCoveragePoint> { point } };
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
        public Dictionary<string, Dictionary<string, List<CodeCoveragePoint>>> Hits { get; } = new Dictionary<string, Dictionary<string, List<CodeCoveragePoint>>>(StringComparer.OrdinalIgnoreCase);

        public void Trace(string message, IScriptExtent extent, ScriptBlock _, int __, string ___, string ____)
        {
            if (_debug && extent?.File != null && CultureInfo.InvariantCulture.CompareInfo.IndexOf(extent.File, _debugFile, CompareOptions.OrdinalIgnoreCase) >= 0)
            {
                var f = Console.ForegroundColor;
                try
                {
                    var dbgm = message?.Trim();
                    if (dbgm != null && (int.Parse(message.Split('+')[0]) != extent.StartLineNumber))
                    {
                        Console.ForegroundColor = ConsoleColor.Red;
                    }
                    else
                    {
                        Console.ForegroundColor = ConsoleColor.Yellow;
                    }
                    Console.WriteLine($"DBG: {message?.Trim()}");
                    Console.WriteLine($"EXP: {extent.File}:{extent.StartLineNumber}:{extent.StartColumnNumber}:{extent.Text}");
                }
                finally
                {
                    Console.ForegroundColor = f;
                }
            }

            // ignore unbound scriptblocks
            if (extent?.File == null)
                return;
            if (!Hits.TryGetValue(extent.File, out var lineColumn))
                return;

            var key2 = $"{extent.StartLineNumber}:{extent.StartColumnNumber}";
            if (!lineColumn.ContainsKey(key2))
                return;

            var points = lineColumn[key2];
            if (points.TrueForAll(a => a.Hit))
            {
                return;
            }

            for (var i = 0; i < points.Count; i++)
            {
                var point = points[i];
                point.Hit = true;
                point.Text = extent.Text;
                points[i] = point;
            }

            lineColumn[key2] = points;
        }

#pragma warning disable IDE0060
        // Profiler v3.1 compatible overload
        public void Trace(IScriptExtent extent, ScriptBlock scriptBlock, int level) => Trace(null, extent, scriptBlock, level, null, null);

        // Profiler v4 compatible overload
        public void Trace(IScriptExtent extent, ScriptBlock scriptBlock, int level, string functionName, string moduleName) => Trace(null, extent, scriptBlock, level, functionName, moduleName);
#pragma warning restore IDE0060
    }
}
