# Helper function to get a XML node from a XPath expression
function Get-XmlNode($xmlDocument, $xPath) {
    return (Select-Xml -Xml $xmlDocument -XPath $xPath | Select-Object -ExpandProperty Node)
}

# Helper function to get the inner text of a XML node from a XPath expression
function Get-XmlInnerText($xmlDocument, $xPath) {
    return (Get-XmlNode $xmlDocument $xPath).InnerText
}

# Helper function to get the value of a XML node from a XPath expression
function Get-XmlValue($xmlDocument, $xPath) {
    return (Get-XmlNode $xmlDocument $xPath).Value
}

# Helper function to get the number of children of a XML node from a XPath expression
function Get-XmlCount($xmlDocument, $xPath) {
    return (Get-XmlNode $xmlDocument $xPath).Count
}

# Special helper function to get the text of the directly following pre element
function Get-NextPreText($xmlDocument, $xPath) {
    return Get-XmlInnerText $xmlDocument "$xPath/following-sibling::*[position()=1][name()='pre']"
}
