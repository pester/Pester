// Vendored from DiffPlex 1.9.0, https://github.com/mmanela/diffplex
// Copyright (c) Matthew Manela. Licensed under the Apache License, Version 2.0.
// See LICENSE.txt and VENDORING.md in this folder.
// Modified by the Pester Team: the namespace is Pester.DiffPlex instead of DiffPlex.
namespace Pester.DiffPlex.Chunkers
{
    public class WordChunker:DelimiterChunker
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