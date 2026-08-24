// Vendored from DiffPlex 1.9.0, https://github.com/mmanela/diffplex
// Copyright (c) Matthew Manela. Licensed under the Apache License, Version 2.0.
// See LICENSE.txt and VENDORING.md in this folder.
// Modified by the Pester Team: the namespace is Pester.DiffPlex instead of DiffPlex.
namespace Pester.DiffPlex.Model
{
    public enum Edit
    {
        None,
        DeleteRight,
        DeleteLeft,
        InsertDown,
        InsertUp
    }

    public class EditLengthResult
    {
        public int EditLength { get; set; }

        public int StartX { get; set; }
        public int EndX { get; set; }
        public int StartY { get; set; }
        public int EndY { get; set; }

        public Edit LastEdit { get; set; }
    }
}