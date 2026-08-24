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