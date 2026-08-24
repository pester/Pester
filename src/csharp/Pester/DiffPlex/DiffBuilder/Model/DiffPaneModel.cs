using System.Collections.Generic;
using System.Linq;

namespace Pester.DiffPlex.DiffBuilder.Model
{
    public class DiffPaneModel
    {
        public List<DiffPiece> Lines { get; }

        public bool HasDifferences
        {
            get { return Lines.Any(x => x.Type != ChangeType.Unchanged); }
        }

        public DiffPaneModel()
        {
            Lines = new List<DiffPiece>();
        }
    }
}