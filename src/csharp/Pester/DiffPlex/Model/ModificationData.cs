using System.Collections.Generic;

namespace Pester.DiffPlex.Model
{
    public class ModificationData
    {
        public int[] HashedPieces { get; set; }

        public string RawData { get; }

        public bool[] Modifications { get; set; }

        public IReadOnlyList<string> Pieces { get; set; }

        public ModificationData(string str)
        {
            RawData = str;
        }
    }
}