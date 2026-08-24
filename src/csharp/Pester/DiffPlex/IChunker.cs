// Vendored from DiffPlex 1.9.0, https://github.com/mmanela/diffplex
// Copyright (c) Matthew Manela. Licensed under the Apache License, Version 2.0.
// See LICENSE.txt and VENDORING.md in this folder.
// Modified by the Pester Team: the namespace is Pester.DiffPlex instead of DiffPlex.
using System.Collections.Generic;

namespace Pester.DiffPlex
{
    /// <summary>
    /// Responsible for how to turn the document into pieces
    /// </summary>
    public interface IChunker
    {
        /// <summary>
        /// Divide text into sub-parts
        /// </summary>
        IReadOnlyList<string> Chunk(string text);
    }
}