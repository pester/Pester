// Vendored from DiffPlex 1.9.0, https://github.com/mmanela/diffplex
// Copyright (c) Matthew Manela. Licensed under the Apache License, Version 2.0.
// See LICENSE.txt and VENDORING.md in this folder.
// Modified by the Pester Team, see VENDORING.md. Rebuild with Update-VendoredDiffPlex.ps1.
using System.Collections.Generic;

namespace Pester.DiffPlex.Model
{
    internal class ModificationData
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