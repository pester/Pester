// Vendored from DiffPlex 1.9.0, https://github.com/mmanela/diffplex
// Copyright (c) Matthew Manela. Licensed under the Apache License, Version 2.0.
// See LICENSE.txt and VENDORING.md in this folder.
// Modified by the Pester Team, see VENDORING.md. Rebuild with Update-VendoredDiffPlex.ps1.
using System.Collections.Generic;
using System.Linq;

namespace Pester.DiffPlex.DiffBuilder.Model
{
    internal class DiffPaneModel
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