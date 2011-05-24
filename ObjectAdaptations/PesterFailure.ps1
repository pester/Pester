Add-Type @'
public class PesterFailure
{
    public string Expected;
    public string Observed;
    
    public PesterFailure(string Expected,string Observed){
        this.Expected = Expected;
        this.Observed = Observed;
    }
}
'@