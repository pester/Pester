// Vendored from DiffPlex 1.9.0, https://github.com/mmanela/diffplex
// Copyright (c) Matthew Manela. Licensed under the Apache License, Version 2.0.
// See LICENSE.txt and VENDORING.md in this folder.
// Modified by the Pester Team, see VENDORING.md. Rebuild with Update-VendoredDiffPlex.ps1.
namespace Pester.DiffPlex.Model
{
    internal enum Edit
    {
        None,
        DeleteRight,
        DeleteLeft,
        InsertDown,
        InsertUp
    }

    internal class EditLengthResult
    {
        public int EditLength { get; set; }

        public int StartX { get; set; }
        public int EndX { get; set; }
        public int StartY { get; set; }
        public int EndY { get; set; }

        public Edit LastEdit { get; set; }
    }
}