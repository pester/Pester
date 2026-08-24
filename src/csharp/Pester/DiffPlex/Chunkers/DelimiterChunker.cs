// Vendored from DiffPlex 1.9.0, https://github.com/mmanela/diffplex
// Copyright (c) Matthew Manela. Licensed under the Apache License, Version 2.0.
// See LICENSE.txt and VENDORING.md in this folder.
// Modified by the Pester Team, see VENDORING.md. Rebuild with Update-VendoredDiffPlex.ps1.
using System;
using System.Collections.Generic;

namespace Pester.DiffPlex.Chunkers
{
    internal class DelimiterChunker : IChunker
    {
        private readonly char[] delimiters;

        public DelimiterChunker(char[] delimiters)
        {
            if (delimiters is null || delimiters.Length == 0)
            {
                throw new ArgumentException($"{nameof(delimiters)} cannot be null or empty.", nameof(delimiters));
            }

            this.delimiters = delimiters;
        }

        public IReadOnlyList<string> Chunk(string str)
        {
            var list = new List<string>();
            int begin = 0;
            bool processingDelim = false;
            int delimBegin = 0;
            for (int i = 0; i < str.Length; i++)
            {
                if (Array.IndexOf(delimiters, str[i]) != -1)
                {
                    if (i >= str.Length - 1)
                    {
                        if (processingDelim)
                        {
                            list.Add(str.Substring(delimBegin, (i + 1 - delimBegin)));
                        }
                        else
                        {
                            list.Add(str.Substring(begin, (i - begin)));
                            list.Add(str.Substring(i, 1));
                        }
                    }
                    else
                    {
                        if (!processingDelim)
                        {
                            // Add everything up to this delimeter as the next chunk (if there is anything)
                            if (i - begin > 0)
                            {
                                list.Add(str.Substring(begin, (i - begin)));
                            }

                            processingDelim = true;
                            delimBegin = i;
                        }
                    }

                    begin = i + 1;
                }
                else
                {
                    if (processingDelim)
                    {
                        if (i - delimBegin > 0)
                        {
                            list.Add(str.Substring(delimBegin, (i - delimBegin)));
                        }

                        processingDelim = false;
                    }

                    // If we are at the end, add the remaining as the last chunk
                    if (i >= str.Length - 1)
                    {
                        list.Add(str.Substring(begin, (i + 1 - begin)));
                    }
                }
            }

            return list;
        }
    }
}