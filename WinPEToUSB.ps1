#Change to admin
param([switch]$Elevated)
function Test-Admin { 
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent()) 
    $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)          }

    if ((Test-Admin) -eq $false) {
         if ($elevated) 
            { } 
         else { 
            Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -noexit -file "{0}" -elevated' -f ($myinvocation.MyCommand.Definition))

              } 
    exit } 
$ver = '1.0'


#### Working Folder
$_WorkingDirectory = "C:\Computer"
$_FilesPackage = '.\USBPrepare.zip'


#Downloading files needed from the server
function GetPEFiles
    { 
        Import-Module BitsTransfer
        New-Item C:\server\USBPrepare -ItemType Directory
        Start-BitsTransfer -Source $($_FilesPackage) -Destination $_WorkingDirectory\Files.zip -TransferType Download -Description "Downloading files needed from the server..."
        Expand-Archive -LiteralPath $_WorkingDirectory\Files.zip -DestinationPath $_WorkingDirectory
        Remove-Item $_WorkingDirectory\Files.zip
    }


if(Test-Path $_WorkingDirectory\USBPrepare\PEFiles\"Deployment Tools"\DandISetEnv.bat) 
    {
        Write-Host "Files OK"
    }
    else
    {

        GetPEFiles
    }


# usbDisk class
class UsbDisks
{
    $DiskNumber
    $index
    $FriendlyName
    $capacidad
}


$DiskIndex = 0 
$Disks = get-disk
$UsbDisks = New-Object System.Collections.ArrayList


foreach($Disk in $Disks)
{
    if($Disk.BusType -eq "USB")
    {
        $CapacityX = [Math]::Round($Disk.Size * .00000000099) + 1
        $UsbDisk = New-Object -TypeName UsbDisks
        $UsbDisk.Index = $DiskIndex
        $UsbDisk.DiskNumber = $Disk.DiskNumber
        $UsbDisk.capacidad = $CapacityX.ToString() + "GB"
        $UsbDisk.FriendlyName = $Disk.FriendlyName + " -- " + $UsbDisk.capacidad
        $UsbDisks.add($UsbDisk)
        $DiskIndex ++
    }
}


######### Form ######################
Add-Type -AssemblyName System.Windows.Forms
$Form = New-Object system.Windows.Forms.Form
$Form.Font = $Font
$Form.Text = 'Load Image to USB' + $ver
$Form.Width = 350
$Form.Height = 150

#Controls
$Label = New-Object System.Windows.Forms.Label
$Label.Text = "Select USB Disk:"
$label.Location = New-Object Drawing.Point 30,10
$Label.AutoSize = $True
$Form.Controls.Add($Label)

$boton1 = New-Object System.Windows.Forms.Button
$boton1.Text = "OK"
$boton1.Location = New-Object Drawing.Point 50,60
$boton1.Width = 100
$form.Controls.add($boton1)


$boton2 = New-Object System.Windows.Forms.Button
$boton2.Text = "Cancel"
$boton2.Location = New-Object Drawing.Point 180,60
$boton2.Width = 100
$form.Controls.add($boton2)

$ComboBox1 = New-Object System.Windows.Forms.ComboBox
$ComboBox1.Items.AddRange($UsbDisks.FriendlyName)
$ComboBox1.Location = New-Object Drawing.Point 15,30
$combobox1.Width = 300
$Combobox1.SelectedIndex = 0
$form.Controls.add($Combobox1)

$boton2.Add_Click({
$form.Close()
})


Function PartUsb
{
    $SelectedDisk =  $UsbDisks[$combobox1.SelectedIndex].Disknumber
    Write-host "Selected Disk: " $SelectedDisk
    Get-Disk $SelectedDisk | Clear-Disk -RemoveOEM -RemoveData -Confirm:$False 
    Set-Disk -Number $SelectedDisk  -PartitionStyle MBR
    New-Partition -DiskNumber $SelectedDisk -Size 1000MB -AssignDriveLetter | Format-Volume -FileSystem FAT32 -NewFileSystemLabel WinPE
    New-Partition -DiskNumber $SelectedDisk -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS -NewFileSystemLabel Archivos
}


$boton1.add_Click({
    PartUsb
    $_UnatendedFiles = "C:\server\USBPrepare\UnatendedInstaller\*"
    $_PartToFiles = Get-WMIObject Win32_Volume | Where-Object{ $_.Label -eq 'Archivos'}
    Copy-Item -Path $_UnatendedFiles  -Recurse -Destination $_PartToFiles.DriveLetter

    $WinPE = Get-WMIObject Win32_Volume | Where-Object{ $_.Label -eq 'WinPE'}
    $Argumentos = '/k ' + $_WorkingDirectory +'\USBPrepare\PEFiles\"Deployment Tools"\DandISetEnv.bat' + " " + $WinPE.DriveLetter
    Write-host "cmd " $Argumentos
    Start-Process -Wait -FilePath cmd -ArgumentList $Argumentos -PassThru
    
})

$Form.ShowDialog()
