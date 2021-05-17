# # assingment needs to be shifted to the correct line and column
# # of parent, unless there is an if
# $a   =    10
# $a   =    ((10))
# $g   =  if ($a -eq 10) { "yes" } else { "no" }

# $b    =   (Start-Sleep 0)

# if ($a -eq 10) {
# $b
# }

# $h = @{
# name =    10
# age =     (start-sleep 1)
# mmm = if ($a -eq 10) { "yes" } else { "no" }
# }
# Start-Sleep 0

# # return needs to be shifted by 7 chars to right (length of 'return'+1)
# function a () {
#     $text = "some text"
#     return ($Text.ToUpper() -replace 'a', 'b')
#  }

#  a


 @("aaa") | ForEach-Object -Process {
    "b"
}
