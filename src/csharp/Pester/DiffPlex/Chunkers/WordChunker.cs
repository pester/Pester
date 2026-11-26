// Vendored from DiffPlex 1.9.0, https://github.com/mmanela/diffplex
// Copyright (c) Matthew Manela. Licensed under the Apache License, Version 2.0.
// See LICENSE.txt and VENDORING.md in this folder.
// Modified by the Pester Team, see VENDORING.md. Rebuild with Update-VendoredDiffPlex.ps1.
namespace Pester.DiffPlex.Chunkers
{
    internal class WordChunker:DelimiterChunker
    {
        private static char[] WordSeparators { get; } = { ' ', '\t', '.', '(', ')', '{', '}', ',', '!', '?', ';' };

        /// <summary>
        /// Gets the default singleton instance of the chunker.
        /// </summary>
        public static WordChunker Instance { get; } = new WordChunker();

        public WordChunker() : base(WordSeparators)
        {
        }
    }
}