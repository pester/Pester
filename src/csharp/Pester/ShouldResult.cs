namespace Pester
{
  public class ShouldResult
  {
    public bool Succeeded { get; set; }
    public string FailureMessage { get; set; }
    public ShouldExpectResult ExpectResult { get; set; }
  }

  public class ShouldExpectResult
  {
    public string Actual { get; set; }
    public string Expected { get; set; }
    public string Because { get; set; }

    public override string ToString()
    {
      return $"Expected: {Expected} Actual: {Actual} Because: {Because}";
    }
  }
}
