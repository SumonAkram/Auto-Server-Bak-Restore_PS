# --- Ensure Windows Server Backup (`wbadmin`) is Installed ---
$Feature = Get-WindowsFeature -Name Windows-Server-Backup
If (!$Feature.Installed) {
    Write-Host "Windows Server Backup (wbadmin) is not installed. Installing now..."
    Install-WindowsFeature -Name Windows-Server-Backup
    Restart-Computer -Force
}

# --- Minimize PowerShell Window Automatically ---
$Sig = @'
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
'@
$Type = Add-Type -MemberDefinition $Sig -Name "WinAPI" -Namespace "Win32" -PassThru
$Handle = (Get-Process -Id $PID).MainWindowHandle
$Type::ShowWindow($Handle, 6)  # 6 = Minimize

# --- Backup Settings ---
$BackupDrive = "G:"  # Root drive where backup is stored
$LogFile = "$BackupDrive\backup_log.txt"
$ErrorLog = "$BackupDrive\backup_error_log.txt"
$VMName = "tm"  # Your VM Name
$RetentionDays = 30  # Keep backups for 30 days

# --- Log Backup Start Time ---
$StartTime = Get-Date
Add-Content -Path $LogFile -Value "Backup Started: $StartTime"

# --- Ensure VSS is Enabled for Hyper-V ---
Enable-VMIntegrationService -VMName $VMName -Name "Volume Shadow Copy" -ErrorAction SilentlyContinue

# --- Run Incremental Backup Using wbadmin ---
$BackupCommand = "wbadmin start backup -backupTarget:$BackupDrive -hyperv:$VMName -vssFull -quiet"
Invoke-Expression $BackupCommand

# --- Wait for Backup to Complete Before Checking Status ---
Start-Sleep -Seconds 30  # Allows process time to complete
$BackupComplete = $false
$Attempts = 0
While (-not $BackupComplete -and $Attempts -lt 20) {
    $CheckBackup = wbadmin get versions | Select-String "Backup time"
    If ($CheckBackup) {
        $BackupComplete = $true
    } Else {
        Start-Sleep -Seconds 30
        $Attempts++
    }
}

# --- Verify If the Backup Actually Exists ---
If ($BackupComplete) {
    $EndTime = Get-Date
    $Duration = $EndTime - $StartTime
    Add-Content -Path $LogFile -Value "Backup Completed Successfully: $EndTime"
    Add-Content -Path $LogFile -Value "Total Backup Time: $($Duration.Hours)h $($Duration.Minutes)m $($Duration.Seconds)s"
    Add-Content -Path $LogFile -Value "Backup Successful. PowerShell will now close."

    # --- Show Success Notification ---
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show("Backup completed successfully!", "Backup Status", "OK", "Information")

    # --- Close PowerShell Window Automatically ---
    Stop-Process -Id $PID
} Else {
    $EndTime = Get-Date
    $Duration = $EndTime - $StartTime
    Add-Content -Path $ErrorLog -Value "❌ Backup Failed: $EndTime"
    Add-Content -Path $ErrorLog -Value "❌ Error Details: No valid backup found!"
    Add-Content -Path $ErrorLog -Value "❌ Total Backup Time: $($Duration.Hours)h $($Duration.Minutes)m $($Duration.Seconds)s"

    # --- Show Failure Notification Only If No Backup Exists ---
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show("Backup Failed! No valid backup found. Check $ErrorLog for details.", "Backup Error", "OK", "Error")
}
