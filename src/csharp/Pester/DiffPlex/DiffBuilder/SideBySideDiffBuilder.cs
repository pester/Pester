// Vendored from DiffPlex 1.9.0, https://github.com/mmanela/diffplex
// Copyright (c) Matthew Manela. Licensed under the Apache License, Version 2.0.
// See LICENSE.txt and VENDORING.md in this folder.
// Modified by the Pester Team, see VENDORING.md. Rebuild with Update-VendoredDiffPlex.ps1.
using System;
using System.Collections.Generic;
using System.Linq;
using Pester.DiffPlex.Chunkers;
using Pester.DiffPlex.DiffBuilder.Model;
using Pester.DiffPlex.Model;

namespace Pester.DiffPlex.DiffBuilder
{
    internal class SideBySideDiffBuilder
    {
        private readonly Differ differ;
        private readonly IChunker lineChunker;
        private readonly IChunker wordChunker;

        private delegate ChangeType PieceBuilder(string oldText, string newText, List<DiffPiece> oldPieces, List<DiffPiece> newPieces, bool ignoreWhitespace, bool ignoreCase);

        public SideBySideDiffBuilder(Differ differ, IChunker lineChunker, IChunker wordChunker)
        {
            this.differ = differ ?? throw new ArgumentNullException(nameof(differ));
            this.lineChunker = lineChunker ?? throw new ArgumentNullException(nameof(lineChunker));
            this.wordChunker = wordChunker ?? throw new ArgumentNullException(nameof(wordChunker));
        }

        public SideBySideDiffModel BuildDiffModel(string oldText, string newText, bool ignoreWhitespace, bool ignoreCase)
        {
            return BuildLineDiff(
                oldText ?? throw new ArgumentNullException(nameof(oldText)),
                newText ?? throw new ArgumentNullException(nameof(newText)),
                ignoreWhitespace,
                ignoreCase);
        }



        private static ChangeType BuildWordDiffPiecesInternal(string oldText, string newText, List<DiffPiece> oldPieces, List<DiffPiece> newPieces, bool ignoreWhiteSpace, bool ignoreCase)
        {
            var diffResult = Differ.Instance.CreateDiffs(oldText, newText, ignoreWhiteSpace, ignoreCase, WordChunker.Instance);
            return BuildDiffPieces(diffResult, oldPieces, newPieces, null, ignoreWhiteSpace, ignoreCase);
        }

        private SideBySideDiffModel BuildLineDiff(string oldText, string newText, bool ignoreWhiteSpace, bool ignoreCase)
        {
            var model = new SideBySideDiffModel();
            var diffResult = differ.CreateDiffs(oldText, newText, ignoreWhiteSpace, ignoreCase, lineChunker);
            BuildDiffPieces(diffResult, model.OldText.Lines, model.NewText.Lines, BuildWordDiffPieces, ignoreWhiteSpace, ignoreCase);

            return model;
        }

        private ChangeType BuildWordDiffPieces(string oldText, string newText, List<DiffPiece> oldPieces, List<DiffPiece> newPieces, bool ignoreWhiteSpace, bool ignoreCase)
        {
            var diffResult = differ.CreateDiffs(oldText, newText, ignoreWhiteSpace: ignoreWhiteSpace, ignoreCase, wordChunker);
            return BuildDiffPieces(diffResult, oldPieces, newPieces, subPieceBuilder: null, ignoreWhiteSpace, ignoreCase);
        }

        private static ChangeType BuildDiffPieces(DiffResult diffResult, List<DiffPiece> oldPieces, List<DiffPiece> newPieces, PieceBuilder subPieceBuilder, bool ignoreWhiteSpace, bool ignoreCase)
        {
            int aPos = 0;
            int bPos = 0;

            foreach (var diffBlock in diffResult.DiffBlocks)
            {
                while (bPos < diffBlock.InsertStartB && aPos < diffBlock.DeleteStartA)
                {
                    oldPieces.Add(new DiffPiece(diffResult.PiecesOld[aPos], ChangeType.Unchanged, aPos + 1));
                    newPieces.Add(new DiffPiece(diffResult.PiecesNew[bPos], ChangeType.Unchanged, bPos + 1));
                    aPos++;
                    bPos++;
                }

                int i = 0;
                for (; i < Math.Min(diffBlock.DeleteCountA, diffBlock.InsertCountB); i++)
                {
                    var oldPiece = new DiffPiece(diffResult.PiecesOld[i + diffBlock.DeleteStartA], ChangeType.Deleted, aPos + 1);
                    var newPiece = new DiffPiece(diffResult.PiecesNew[i + diffBlock.InsertStartB], ChangeType.Inserted, bPos + 1);

                    if (subPieceBuilder != null)
                    {
                        var subChangeSummary = subPieceBuilder(diffResult.PiecesOld[aPos], diffResult.PiecesNew[bPos], oldPiece.SubPieces, newPiece.SubPieces, ignoreWhiteSpace, ignoreCase);
                        newPiece.Type = oldPiece.Type = subChangeSummary;
                    }

                    oldPieces.Add(oldPiece);
                    newPieces.Add(newPiece);
                    aPos++;
                    bPos++;
                }

                if (diffBlock.DeleteCountA > diffBlock.InsertCountB)
                {
                    for (; i < diffBlock.DeleteCountA; i++)
                    {
                        oldPieces.Add(new DiffPiece(diffResult.PiecesOld[i + diffBlock.DeleteStartA], ChangeType.Deleted, aPos + 1));
                        newPieces.Add(new DiffPiece());
                        aPos++;
                    }
                }
                else
                {
                    for (; i < diffBlock.InsertCountB; i++)
                    {
                        newPieces.Add(new DiffPiece(diffResult.PiecesNew[i + diffBlock.InsertStartB], ChangeType.Inserted, bPos + 1));
                        oldPieces.Add(new DiffPiece());
                        bPos++;
                    }
                }
            }

            while (bPos < diffResult.PiecesNew.Count && aPos < diffResult.PiecesOld.Count)
            {
                oldPieces.Add(new DiffPiece(diffResult.PiecesOld[aPos], ChangeType.Unchanged, aPos + 1));
                newPieces.Add(new DiffPiece(diffResult.PiecesNew[bPos], ChangeType.Unchanged, bPos + 1));
                aPos++;
                bPos++;
            }

            // Consider the whole diff as "modified" if we found any change, otherwise we consider it unchanged
            if(oldPieces.Any(x => x.Type is ChangeType.Modified or ChangeType.Inserted or ChangeType.Deleted))
            {
                return ChangeType.Modified;
            }

            if (newPieces.Any(x => x.Type is ChangeType.Modified or ChangeType.Inserted or ChangeType.Deleted))
            {
                return ChangeType.Modified;
            }

            return ChangeType.Unchanged;
        }
    }
}