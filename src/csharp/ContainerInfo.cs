namespace Pester
{
    public class ContainerInfo
    {
        public static ContainerInfo Create()
        {
            return new ContainerInfo();
        }

        public string Type { get; set; } = "File";
        public object Item { get; set; }
    }
}