// Vendored from DiffPlex 1.9.0, https://github.com/mmanela/diffplex
// Copyright (c) Matthew Manela. Licensed under the Apache License, Version 2.0.
// See LICENSE.txt and VENDORING.md in this folder.
// Modified by the Pester Team: the namespace is Pester.DiffPlex instead of DiffPlex.
namespace Pester.DiffPlex.DiffBuilder.Model
{
    /// <summary>
    /// A model which represents differences between to texts to be shown side by side
    /// </summary>
    public class SideBySideDiffModel
    {
        public DiffPaneModel OldText { get; }
        public DiffPaneModel NewText { get; }

        public SideBySideDiffModel()
        {
            OldText = new DiffPaneModel();
            NewText = new DiffPaneModel();
        }
    }
}