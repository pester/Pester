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

        public string CoverageReport { get; set; }

        public long CommandsAnalyzedCount { get; set; }
        public long CommandsExecutedCount { get; set; }
        public long CommandsMissedCount { get; set; }
        public long FilesAnalyzedCount { get; set; }

        public List<object> CommandsMissed = new List<object>();
        public List<object> CommandsExecuted = new List<object>();
        public List<object> FilesAnalyzed = new List<object>();

        public override string ToString()
        {
            return string.Format("{0:N2} %", CoveragePercent);
        }
    }
}