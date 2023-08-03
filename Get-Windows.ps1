$ISOs = "C:\ISOs"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$URL = @()
$URL = @("https://www.microsoft.com/en-us/evalcenter/download-windows-server-2016","Srv2016"),
("https://www.microsoft.com/en-us/evalcenter/download-windows-server-2019","Srv2019"),
("https://www.microsoft.com/en-us/evalcenter/download-windows-server-2022","Srv2022"),
("https://www.microsoft.com/en-us/evalcenter/download-windows-10-enterprise","Win10"),
("https://www.microsoft.com/en-us/evalcenter/download-windows-11-enterprise","Win11") 

if (Test-Path -Path $ISOs) { 
    Write-Host "ISOs path exists"
    } else {
    mkdir $ISOs
    Write-Host "ISOs path now exists"
}

function New-IsoFile 
{  
  <# .Synopsis Creates a new .iso file .Description The New-IsoFile cmdlet creates a new .iso file containing content from chosen folders .
  Example New-IsoFile "c:\tools","c:Downloads\utils" This command creates a .iso file in $env:temp folder (default location) that contains 
  c:\tools and c:\downloads\utils folders. The folders themselves are included at the root of the .iso image. 
  .Example New-IsoFile -FromClipboard -Verbose 
  Before running this command, select and copy (Ctrl-C) files/folders in Explorer first. 
  .Example dir c:\WinPE | New-IsoFile -Path c:\temp\WinPE.iso -BootFile "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\efisys.bin" 
  -Media DVDPLUSR -Title "WinPE" 
  This command creates a bootable .iso file containing the content from 
  c:\WinPE folder, but the folder itself isn't included. 
  Boot file etfsboot.com can be found in Windows ADK. Refer to IMAPI_MEDIA_PHYSICAL_TYPE enumeration for possible media types: 
  http://msdn.microsoft.com/en-us/library/windows/desktop/aa366217(v=vs.85).aspx .Notes NAME: New-IsoFile AUTHOR: Chris Wu LASTEDIT: 03/23/2016 14:46:50 #> 
   
  [CmdletBinding(DefaultParameterSetName='Source')]Param( 
    [parameter(Position=1,Mandatory=$true,ValueFromPipeline=$true, ParameterSetName='Source')]$Source,  
    [parameter(Position=2)][string]$Path = "$env:temp\$((Get-Date).ToString('yyyyMMdd-HHmmss.ffff')).iso",  
    [ValidateScript({Test-Path -LiteralPath $_ -PathType Leaf})][string]$BootFile = $null, 
    [ValidateSet('CDR','CDRW','DVDRAM','DVDPLUSR','DVDPLUSRW','DVDPLUSR_DUALLAYER','DVDDASHR','DVDDASHRW','DVDDASHR_DUALLAYER','DISK','DVDPLUSRW_DUALLAYER','BDR','BDRE')][string] $Media = 'DVDPLUSRW_DUALLAYER', 
    [string]$Title = (Get-Date).ToString("yyyyMMdd-HHmmss.ffff"),  
    [switch]$Force, 
    [parameter(ParameterSetName='Clipboard')][switch]$FromClipboard 
  ) 
  
  Begin {  
    ($cp = new-object System.CodeDom.Compiler.CompilerParameters).CompilerOptions = '/unsafe' 
    if (!('ISOFile' -as [type])) {  
      Add-Type -CompilerParameters $cp -TypeDefinition @'
public class ISOFile  
{ 
  public unsafe static void Create(string Path, object Stream, int BlockSize, int TotalBlocks)  
  {  
    int bytes = 0;  
    byte[] buf = new byte[BlockSize];  
    var ptr = (System.IntPtr)(&bytes);  
    var o = System.IO.File.OpenWrite(Path);  
    var i = Stream as System.Runtime.InteropServices.ComTypes.IStream;  
   
    if (o != null) { 
      while (TotalBlocks-- > 0) {  
        i.Read(buf, BlockSize, ptr); o.Write(buf, 0, bytes);  
      }  
      o.Flush(); o.Close();  
    } 
  } 
}  
'@  
    } 
   
    if ($BootFile) { 
      if('BDR','BDRE' -contains $Media) { Write-Warning "Bootable image doesn't seem to work with media type $Media" } 
      ($Stream = New-Object -ComObject ADODB.Stream -Property @{Type=1}).Open()  # adFileTypeBinary 
      $Stream.LoadFromFile((Get-Item -LiteralPath $BootFile).Fullname) 
      ($Boot = New-Object -ComObject IMAPI2FS.BootOptions).AssignBootImage($Stream) 
    } 
  
    $MediaType = @('UNKNOWN','CDROM','CDR','CDRW','DVDROM','DVDRAM','DVDPLUSR','DVDPLUSRW','DVDPLUSR_DUALLAYER','DVDDASHR','DVDDASHRW','DVDDASHR_DUALLAYER','DISK','DVDPLUSRW_DUALLAYER','HDDVDROM','HDDVDR','HDDVDRAM','BDROM','BDR','BDRE') 
  
    Write-Verbose -Message "Selected media type is $Media with value $($MediaType.IndexOf($Media))"
    ($Image = New-Object -com IMAPI2FS.MsftFileSystemImage -Property @{VolumeName=$Title}).ChooseImageDefaultsForMediaType($MediaType.IndexOf($Media)) 
   
    if (!($Target = New-Item -Path $Path -ItemType File -Force:$Force -ErrorAction SilentlyContinue)) { Write-Error -Message "Cannot create file $Path. Use -Force parameter to overwrite if the target file already exists."; break } 
  }  
  
  Process { 
    if($FromClipboard) { 
      if($PSVersionTable.PSVersion.Major -lt 5) { Write-Error -Message 'The -FromClipboard parameter is only supported on PowerShell v5 or higher'; break } 
      $Source = Get-Clipboard -Format FileDropList 
    } 
  
    foreach($item in $Source) { 
      if($item -isnot [System.IO.FileInfo] -and $item -isnot [System.IO.DirectoryInfo]) { 
        $item = Get-Item -LiteralPath $item
      } 
  
      if($item) { 
        Write-Verbose -Message "Adding item to the target image: $($item.FullName)"
        try { $Image.Root.AddTree($item.FullName, $true) } catch { Write-Error -Message ($_.Exception.Message.Trim() + ' Try a different media type.') } 
      } 
    } 
  } 
  
  End {  
    if ($Boot) { $Image.BootImageOptions=$Boot }  
    $Result = $Image.CreateResultImage()  
    [ISOFile]::Create($Target.FullName,$Result.ImageStream,$Result.BlockSize,$Result.TotalBlocks) 
    Write-Verbose -Message "Target image ($($Target.FullName)) has been created"
    $Target
  } 
} 



ForEach ($link in $URL) {
    if (Test-Path -Path "$ISOs\$($link[1])") { 
        Write-Host "$ISOs\$($link[1]) path exists"
        } else {
        mkdir "$ISOs\$($link[1])"
        Write-Host "$ISOs\$($link[1]) path now exists"
    }
        if (Test-Path -Path "$ISOs\$($link[1])\mount") { 
        Write-Host "$ISOs\$($link[1])\mount path exists"
        } else {
        mkdir "$ISOs\$($link[1])\mount"
        Write-Host "$ISOs\$($link[1])\mount path now exists"
    }
        if (Test-Path -Path "$ISOs\$($link[1])\source") { 
        Write-Host "$ISOs\$($link[1])\source path exists"
        } else {
        mkdir "$ISOs\$($link[1])\source"
        Write-Host "$ISOs\$($link[1])\source path now exists"
    }
#        if (Test-Path -Path "$ISOs\$($link[1])\updatecab") { 
#        Write-Host "$ISOs\$($link[1])\updatecab path exists"
#        } else {
#        mkdir "$ISOs\$($link[1])\updatecab"
#        Write-Host "$ISOs\$($link[1])\updatecab path now exists"
#    }
    $OSURL = (((Invoke-WebRequest -UseBasicParsing -Uri $($link[0])).Links | 
        Where-Object {($_.href -like "https://go.microsoft.com/fwlink/p/?linkID=*&culture=en-us&country=US")`
            -and ($_.outerHTML -like "*Download Windows*")`
            -and ($_.outerHTML -notlike "*Azure*")`
            -and ($_.outerHTML -notlike "*32-bit*")`
            -and ($_.outerHTML -notlike "*LTSC*")`
            -and ($_.outerHTML -notlike "*VHD*")
        }).href)

        Write-Host "Downloading $($link[1])..."
        Start-BitsTransfer -Source $OSURL -Destination "$ISOs\$($link[1])\$($link[1])_Eval.iso" -Priority high
        Write-Host "Downloading of Eval ISO $($link[1]) complete."

        
        Write-Host "Mounting $ISOs\$($link[1])\$($link[1])_Eval.iso"
        $mountResult = (Mount-DiskImage -ImagePath "$ISOs\$($link[1])\$($link[1])_Eval.iso" -StorageType ISO -PassThru)
        sleep 3
        $driveLetter = ($mountResult | Get-Volume).DriveLetter
        
        Write-Host "Copying $ISOs\$($link[1])\$($link[1])_Eval.iso source to disk at $ISOs\$($link[1])\source"
        robocopy "${driveLetter}:\" "$ISOs\$($link[1])\source" /MIR
        
        Write-Host "Done copying source from Eval ISO"
        Write-Host "Unmounting $ISOs\$($link[1])\$($link[1])_Eval.iso"
        sleep 3
        # Nice dismount
        # Dismount-DiskImage -ImagePath $ISOs\$($link[1])\$($link[1])_Eval.iso
        
        # Aggressive dismount all.
        Get-Volume | 
            Where-Object DriveType -eq 'CD-ROM' |
                ForEach-Object {
            Get-DiskImage -DevicePath  $_.Path.trimend('\') -EA SilentlyContinue
                } |
                Dismount-DiskImage

         # Patch Wim
         $instwim = "$ISOs\$($link[1])\source\sources\install.wim"
         if (Test-Path -Path $instwim) { 
         Set-ItemProperty -Path "$instwim" -Name IsReadOnly -Value $false
    $imageindexes=(Get-WindowsImage -ImagePath "$instwim").ImageIndex
      foreach ($index in $imageindexes) {
            $i=(Get-WindowsImage -ImagePath "$instwim" -Index $index) | Select ImageName,ImagePath,ImageIndex,InstallationType,Version,Build,Architecture,ProductType
            $ImageName = ($i).ImageName
            $ImagePath = ($i).ImagePath
            $Index = ($i).ImageIndex
            $InstallationType = ($i).InstallationType # Contains Client or Server
            #$Version = ($i).Version
            $Build = ($i).Build
            $Architecture = ($i).Architecture #x64 #x386 #ARM64 #x386=0 x64=9
            #$ProductType = ($i).ProductType
            #Write-host "$ImageName, $Index, $InstallationType, $Version, $Build, $Architecture, $ProductType" 
            
            dism /mount-wim /wimfile:"$instwim" /mountdir:"$ISOs\$($link[1])\mount" /index:$index
           
if(($InstallationType -like "*Client*") -and ($ImageName -like "*Windows*11*"))
{   
    switch ($Build) 
    { 
        22000 {$key = "XGVPP-NMH47-7TTHJ-W3FW7-8HV2C"} # = "Windows 11 21H2"}
        22621 {$key = "XGVPP-NMH47-7TTHJ-W3FW7-8HV2C"} # = "Windows 11 22H2"}
    }
    dism /image:"$ISOs\$($link[1])\mount" /set-edition:Enterprise /AcceptEula /ProductKey:"$key"
}

if(($InstallationType -like "*Client*") -and ($ImageName -like "*Windows*10*"))
{
    switch ($Build) 
    { 
        10240 {$key = "NPPR9-FWDCX-D2C8J-H872K-2YT43"} # = "Windows 10 1507"}
        10586 {$key = "NPPR9-FWDCX-D2C8J-H872K-2YT43"} # = "Windows 10 1511"}
        14393 {$key = "NPPR9-FWDCX-D2C8J-H872K-2YT43"} # = "Windows 10 1607"}
        15063 {$key = "NPPR9-FWDCX-D2C8J-H872K-2YT43"} # = "Windows 10 1703"}
        16299 {$key = "NPPR9-FWDCX-D2C8J-H872K-2YT43"} # = "Windows 10 1709"}
        17134 {$key = "NPPR9-FWDCX-D2C8J-H872K-2YT43"} # = "Windows 10 1803"}
        17763 {$key = "NPPR9-FWDCX-D2C8J-H872K-2YT43"} # = "Windows 10 1809"}
        18362 {$key = "NPPR9-FWDCX-D2C8J-H872K-2YT43"} # = "Windows 10 1903"}
        18363 {$key = "NPPR9-FWDCX-D2C8J-H872K-2YT43"} # = "Windows 10 1909"}
        19041 {$key = "NPPR9-FWDCX-D2C8J-H872K-2YT43"} # = "Windows 10 20H1"}
        19042 {$key = "NPPR9-FWDCX-D2C8J-H872K-2YT43"} # = "Windows 10 20H2"}
        19043 {$key = "NPPR9-FWDCX-D2C8J-H872K-2YT43"} # = "Windows 10 21H1"}
        19044 {$key = "NPPR9-FWDCX-D2C8J-H872K-2YT43"} # = "Windows 10 21H2"}
        19045 {$key = "NPPR9-FWDCX-D2C8J-H872K-2YT43"} # = "Windows 10 22H2"}
    }
    dism /image:"$ISOs\$($link[1])\mount" /set-edition:Enterprise /AcceptEula /ProductKey:"$key"
}

if(($InstallationType -like "*Server*") -and ($ImageName -like "*Server*Standard*"))
{
    switch ($Build) 
    {
        
        #3790 {$key = "Windows Server 2003 R2"} #EOL
        #6001 {$key = "Windows Server 2008"} #EOL
        #7600 {$key = "Windows Server 2008 SP1"} #EOL
        #7601 {$key = "Windows Server 2008 R2"} #EOL    
        #9200 {$key = "Windows Server 2012"}  #EOL
        #9600 {$key = "Windows Server 2012 R2"} #EOL
        14393 {$key = "WC2BQ-8NRM3-FDDYY-2BFGV-KHKQY"} #Windows Server 2016 Standard
        17763 {$key = "N69G4-B89J2-4G8F4-WWYCC-J464C"} #Windows Server 2019 Standard
        20348 {$key = "VDYBN-27WPP-V4HQT-9VMD4-VMK7H"} #Windows Server 2022 Standard
    }
    dism /image:"$ISOs\$($link[1])\mount" /set-edition:ServerStandard /AcceptEula /ProductKey:"$key"
}

if(($InstallationType -like "*Server*") -and ($ImageName -like "*Server*Datacenter*"))
{
    switch ($Build) 
    {
        
        #3790 {$key = "Windows Server 2003 R2"} #EOL
        #6001 {$key = "Windows Server 2008"} #EOL
        #7600 {$key = "Windows Server 2008 SP1"} #EOL
        #7601 {$key = "Windows Server 2008 R2"} #EOL    
        #9200 {$key = "Windows Server 2012"}  #EOL
        #9600 {$key = "Windows Server 2012 R2"} #EOL
        14393 {$key = "CB7KF-BWN84-R7R2Y-793K2-8XDDG"} #Windows Server 2016 Datacenter
        17763 {$key = "WMDGN-G9PQG-XVVXX-R3X43-63DFG"} #Windows Server 2019 Datacenter
        20348 {$key = "WX4NM-KYWYW-QJJR4-XV3QB-6VM33"} #Windows Server 2022 Datacenter
    }
    dism /image:"$ISOs\$($link[1])\mount" /set-edition:ServerDatacenter /AcceptEula /ProductKey:"$key"
}

            #}
        }
         dism /unmount-wim /mountdir:"$ISOs\$($link[1])\mount" /commit
         dir "$ISOs\$($link[1])\source" | New-IsoFile -Path "$ISOs\$($link[1])\$($link[1]).iso" -BootFile "$ISOs\$($link[1])\source\efi\microsoft\boot\efisys.bin" -Title "$($link[1])" -Force

    } else {
            Write-host "No Install.wim file located in $ISOs\$($link[1])\source\sources"
            Exit 99
         }
      }


# Get a list of all mounted drives
$mountedDrives = Get-WindowsImage -Mounted | Select-Object -ExpandProperty MountPath

# Iterate through the list and dismount each drive
foreach ($drive in $mountedDrives) {
    Write-Host "Unmounting drive: $drive"
    Dismount-WindowsImage -Path $drive
}
        # Aggressive dismount all.
        Get-Volume | 
            Where-Object DriveType -eq 'CD-ROM' |
                ForEach-Object {
            Get-DiskImage -DevicePath  $_.Path.trimend('\') -EA SilentlyContinue
                } |
                Dismount-DiskImage
