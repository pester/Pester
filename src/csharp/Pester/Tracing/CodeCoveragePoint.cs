namespace Pester.Tracing
{
    public struct CodeCoveragePoint
    {
        public static CodeCoveragePoint Create(string path, int line, int column, int bpLine, int bpColumn, string astText)
        {
            return new CodeCoveragePoint(path, line, column, bpLine, bpColumn, astText);
        }

        public CodeCoveragePoint(string path, int line, int column, int bpLine, int bpColumn, string astText)
        {
            Path = path;
            Line = line;
            Column = column;
            BpColumn = bpColumn;
            BpLine = bpLine;
            AstText = astText;

            // those are not for users to set,
            // we use them to make CC output easier to debug
            // because this will show in list of hits what we think
            // should or should not hit, for performance just bool 
            // would be enough
            Text = default;
            Hit = false;
        }

        public int Line;
        public int Column;
        public int BpLine;
        public int BpColumn;
        public string Path;
        public string AstText;

        // those are not for users to set,
        // we use them to make CC output easier to debug
        // because this will show in list of hits what we think
        // should or should not hit, for performance just bool 
        // would be enough
        public string Text;
        public bool Hit;

        public override string ToString()
        {
            return $"{Hit}:'{AstText}':{Line}:{Column}:{Path}";
        }
    }
}
