# Get-Full-Windows-ISOs
Download Eval copies of Windows and convert them EVAL to Full ISO Standard/DataCentre/Enterprise etc<br>
legally. .. i believe<br>
Work in Progress but all parts work independently. Just putting them together. <br>
<br>
Download Eval ISOs from MS.<br>
Mount ISO.<br>
Copy ISO source to folder.<br>
DISM add key to Install.wim and set version to Full version Enterprise/Standard/Datacentre/etc<br>
<br>
Adds KMS key - now needs fixing<br>
Setting Version - now needs fixing<br>
<br>
Use New-IsoFile function to create ISO (With thanks! by Chris Wu)<br>
<br>
Have a coffee.<br>

<br><br>
To do:<br>
Change the Win 10/11 to filter type and add their keys correctly. Not build number<br>
Dont just put the enterprise key in for home. add the home key amongst others<br>
Have a better multidimentional array fro Windows tye including key. That could the size and complexity lines by a lot. (find Rohans Suggestion from wk!) <br>
<br>
Add CAB updates?<br>
Clean up<br>
Remove EVAL iso at the end<br>
Remove Source folder at the end (After testing)<br>
