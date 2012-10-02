Add-Type -language CSharp @'
public class PesterFailure
{
    public string Expected;
    public string Observed;

    public PesterFailure(string Expected,string Observed){
        this.Expected = Expected;
        this.Observed = Observed;
    }
    public override string ToString(){
        return string.Format("Expected: {0}. But was: {1}", Expected, Observed);
    }
}
'@
