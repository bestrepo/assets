 Param(
     [securestring]
     $test

 )
$StandardString = ConvertFrom-SecureString -Key $test
Out-File -FilePath C:\Test\1.txt -InputObject $StandardString 