using System.Collections.Generic;

namespace Pester
{
    public class CodeCoverage

    {
        public static CodeCoverage Create()
        {
            return new CodeCoverage();
        }

        public decimal CoveragePercent { get; set; }
        public decimal CoveragePercentTarget { get; set; }

        public string CoverageReport { get; set; }

        public long CommandsAnalyzedCount { get; set; }
        public long CommandsExecutedCount { get; set; }
        public long CommandsMissedCount { get; set; }
        public long FilesAnalyzedCount { get; set; }

        public List<object> CommandsMissed = new();
        public List<object> CommandsExecuted = new();
        public List<object> FilesAnalyzed = new();

        public override string ToString()
        {
            return string.Format("{0:0.##}% / {1:0.##}%", CoveragePercent, CoveragePercentTarget);
        }
    }
}
