// Vendored from DiffPlex 1.9.0, https://github.com/mmanela/diffplex
// Copyright (c) Matthew Manela. Licensed under the Apache License, Version 2.0.
// See LICENSE.txt and VENDORING.md in this folder.
// Modified by the Pester Team: the namespace is Pester.DiffPlex instead of DiffPlex.
using System.Collections.Generic;

namespace Pester.DiffPlex.Model
{
    /// <summary>
    /// The result of diffing two pieces of text
    /// </summary>
    public class DiffResult
    {
        /// <summary>
        /// The chunked pieces of the old text
        /// </summary>
        public IReadOnlyList<string> PiecesOld { get; }

        /// <summary>
        /// The chunked pieces of the new text
        /// </summary>
        public IReadOnlyList<string> PiecesNew { get; }


        /// <summary>
        /// A collection of DiffBlocks which details deletions and insertions
        /// </summary>
        public IList<DiffBlock> DiffBlocks { get; }

        public DiffResult(IReadOnlyList<string> piecesOld, IReadOnlyList<string> piecesNew, IList<DiffBlock> blocks)
        {
            PiecesOld = piecesOld;
            PiecesNew = piecesNew;
            DiffBlocks = blocks;
        }
    }
}