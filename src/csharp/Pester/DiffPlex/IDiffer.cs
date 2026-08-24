// Vendored from DiffPlex 1.9.0, https://github.com/mmanela/diffplex
// Copyright (c) Matthew Manela. Licensed under the Apache License, Version 2.0.
// See LICENSE.txt and VENDORING.md in this folder.
// Modified by the Pester Team: the namespace is Pester.DiffPlex instead of DiffPlex.
using System;
using Pester.DiffPlex.Model;

namespace Pester.DiffPlex
{
    /// <summary>
    /// Responsible for generating differences between texts
    /// </summary>
    public interface IDiffer
    {
        [Obsolete("Use CreateDiffs method instead", false)]
        DiffResult CreateLineDiffs(string oldText, string newText, bool ignoreWhitespace);
        
        [Obsolete("Use CreateDiffs method instead", false)]
        DiffResult CreateLineDiffs(string oldText, string newText, bool ignoreWhitespace, bool ignoreCase);
        
        [Obsolete("Use CreateDiffs method instead", false)]
        DiffResult CreateCharacterDiffs(string oldText, string newText, bool ignoreWhitespace);
        
        [Obsolete("Use CreateDiffs method instead", false)]
        DiffResult CreateCharacterDiffs(string oldText, string newText, bool ignoreWhitespace, bool ignoreCase);
        
        [Obsolete("Use CreateDiffs method instead", false)]
        DiffResult CreateWordDiffs(string oldText, string newText, bool ignoreWhitespace, char[] separators);
        
        [Obsolete("Use CreateDiffs method instead", false)]
        DiffResult CreateWordDiffs(string oldText, string newText, bool ignoreWhitespace, bool ignoreCase, char[] separators);
        
        [Obsolete("Use CreateDiffs method instead", false)]
        DiffResult CreateCustomDiffs(string oldText, string newText, bool ignoreWhiteSpace, Func<string, string[]> chunker);
        
        [Obsolete("Use CreateDiffs method instead", false)] 
        DiffResult CreateCustomDiffs(string oldText, string newText, bool ignoreWhiteSpace, bool ignoreCase, Func<string, string[]> chunker);

        /// <summary>
        /// Creates a diff by comparing text line by line.
        /// </summary>
        /// <param name="oldText">The old text.</param>
        /// <param name="newText">The new text.</param>
        /// <param name="ignoreWhiteSpace">If set to <see langword="true"/> will ignore white space when determining if lines are the same.</param>
        /// <param name="ignoreCase">Determine if the text comparision is case sensitive or not</param>
        /// <param name="chunker">Component responsible for tokenizing the compared texts</param>
        /// <returns>A <see cref="DiffResult"/> object which details the differences</returns>
        DiffResult CreateDiffs(string oldText, string newText, bool ignoreWhiteSpace, bool ignoreCase, IChunker chunker);
    }
}