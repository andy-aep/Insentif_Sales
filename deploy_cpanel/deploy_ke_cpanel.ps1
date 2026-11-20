$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir
$ConfigPath = Join-Path $ScriptDir 'deploy_config.json'
$ExamplePath = Join-Path $ScriptDir 'deploy_config.example.json'

Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "  AUTO DEPLOY KE CPANEL (WinSCP Sync BE & FE)        " -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Cek WinSCP
$winScpCandidates = @(
    'C:\Program Files (x86)\WinSCP\WinSCP.com',
    'C:\Program Files\WinSCP\WinSCP.com',
    "$env:LOCALAPPDATA\Programs\WinSCP\WinSCP.com"
)
$WinScpPath = $winScpCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $WinScpPath) {
    Write-Host "[!] WinSCP belum terinstall di komputer ini." -ForegroundColor Yellow
    $installChoice = Read-Host "Install WinSCP otomatis via winget sekarang? (y/n)"
    if ($installChoice -eq 'y' -or $installChoice -eq 'Y') {
        winget install WinSCP.WinSCP --accept-source-agreements --accept-package-agreements
        $WinScpPath = $winScpCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    }
    if (-not $WinScpPath) {
        Write-Host "[X] Silakan install WinSCP dari https://winscp.net lalu jalankan ulang script ini." -ForegroundColor Red
        exit 1
    }
}

# 2. Pastikan deploy_config.json ada
if (-not (Test-Path $ConfigPath)) {
    Copy-Item $ExamplePath $ConfigPath -Force
    Write-Host "[!] File deploy_config.json baru dibuat di:" -ForegroundColor Yellow
    Write-Host "    $ConfigPath" -ForegroundColor White
    notepad.exe $ConfigPath
    exit 0
}

$cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($cfg.host) -or $cfg.username -eq 'ISI_USERNAME_FTP_CPANEL') {
    Write-Host "[!] Harap lengkapi host & username di deploy_config.json terlebih dahulu." -ForegroundColor Red
    notepad.exe $ConfigPath
    exit 1
}

# 3. Sinkronkan kode lokal BE & FE terbaru ke deploy_cpanel terlebih dahulu
Write-Host "[1/4] Menyinkronkan kode BE terbaru ke deploy_cpanel\insentif_be..." -ForegroundColor Green
$beSrc = Join-Path $RootDir 'BE'
$beDst = Join-Path $ScriptDir 'insentif_be'
foreach ($dir in @('app', 'config', 'database', 'resources', 'routes', 'public')) {
    robocopy "$beSrc\$dir" "$beDst\$dir" /MIR /NFL /NDL /NJH /NJS /NC /NS | Out-Null
}
Copy-Item "$beSrc\composer.json", "$beSrc\composer.lock", "$beSrc\artisan" "$beDst\" -Force

$feBuild = Join-Path $RootDir 'FE\build\web'
$feDst = Join-Path $ScriptDir 'insentif_fe'
if (Test-Path $feBuild) {
    Write-Host "[2/4] Menyinkronkan hasil build FE terbaru ke deploy_cpanel\insentif_fe..." -ForegroundColor Green
    Get-ChildItem $feDst -Force | Remove-Item -Recurse -Force
    Copy-Item "$feBuild\*" "$feDst\" -Recurse -Force

    # Cache-busting untuk Cloudflare CDN & Browser pada index.html dan flutter_bootstrap.js
    $buildVer = Get-Date -Format 'yyyyMMddHHmmss'
    $idxFile = Join-Path $feDst 'index.html'
    if (Test-Path $idxFile) {
        $idxText = Get-Content $idxFile -Raw
        $idxText = $idxText -replace 'flutter_bootstrap\.js(\?v=[0-9]+)?', "flutter_bootstrap.js?v=$buildVer"
        Set-Content -Path $idxFile -Value $idxText -Encoding UTF8
    }
    $bootFile = Join-Path $feDst 'flutter_bootstrap.js'
    if (Test-Path $bootFile) {
        $bootText = Get-Content $bootFile -Raw
        $bootText = $bootText -replace 'main\.dart\.js(\?v=[0-9]+)?', "main.dart.js?v=$buildVer"
        Set-Content -Path $bootFile -Value $bootText -Encoding UTF8
    }
}

$proto = if ($cfg.protocol) { "$($cfg.protocol)".ToLower() } else { 'sftp' }
$port = if ($cfg.port) { $cfg.port } else { if ($proto -eq 'sftp') { 22 } else { 21 } }
$encodedUser = [System.Uri]::EscapeDataString($cfg.username)

Write-Host ""
Write-Host "Target Server : ${proto}://$($cfg.username)@$($cfg.host):${port}" -ForegroundColor Cyan
Write-Host "Folder BE     : $($cfg.remote_be_path)" -ForegroundColor Cyan
Write-Host "Folder FE     : $($cfg.remote_fe_path)" -ForegroundColor Cyan

$sshKeyPem = Join-Path $env:USERPROFILE '.ssh\cpanel_insentif_rsa'
$sshKeyPpk = Join-Path $env:USERPROFILE '.ssh\cpanel_insentif_rsa.ppk'

if ($proto -eq 'sftp' -and (Test-Path $sshKeyPem)) {
    if (-not (Test-Path $sshKeyPpk)) {
        & $WinScpPath /keygen "$sshKeyPem" /output="$sshKeyPpk" | Out-Null
    }
    Write-Host "Autentikasi   : Menggunakan SSH Key ($sshKeyPpk) - Tanpa Password" -ForegroundColor Green
    $openCmd = "open sftp://${encodedUser}@$($cfg.host):${port}/ -hostkey=""*"" -privatekey=""$sshKeyPpk"""
} else {
    $secPass = Read-Host "Masukkan Password FTP/SFTP cPanel" -AsSecureString
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secPass)
    $plainPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

    if ([string]::IsNullOrWhiteSpace($plainPass)) {
        Write-Host "[X] Password tidak boleh kosong." -ForegroundColor Red
        exit 1
    }
    $encodedPass = [System.Uri]::EscapeDataString($plainPass)
    $openCmd = if ($proto -eq 'sftp') {
        "open sftp://${encodedUser}:${encodedPass}@$($cfg.host):${port}/ -hostkey=""*"""
    } elseif ($proto -eq 'ftps' -or $proto -eq 'ftpes') {
        "open ftpes://${encodedUser}:${encodedPass}@$($cfg.host):${port}/ -certificate=""*"""
    } else {
        "open ftp://${encodedUser}:${encodedPass}@$($cfg.host):${port}/"
    }
}

$beRemote = $cfg.remote_be_path.TrimEnd('/')
$feRemote = $cfg.remote_fe_path.TrimEnd('/')

$winScpScript = @"
option batch abort
option confirm off
$openCmd
synchronize remote "$beDst\app" "$beRemote/app" -delete
synchronize remote "$beDst\config" "$beRemote/config" -delete
synchronize remote "$beDst\database" "$beRemote/database" -delete
synchronize remote "$beDst\routes" "$beRemote/routes" -delete
synchronize remote "$beDst\resources" "$beRemote/resources" -delete
put "$beDst\composer.json" "$beRemote/"
put "$beDst\composer.lock" "$beRemote/"
synchronize remote "$feDst" "$feRemote" -delete -filemask="| .well-known/; cgi-bin/"
exit
"@

$tmpScript = Join-Path $env:TEMP "winscp_deploy_$(Get-Date -Format 'yyyyMMddHHmmss').txt"
Set-Content -Path $tmpScript -Value $winScpScript -Encoding UTF8

try {
    Write-Host "[3/4] Mengunggah file yang berubah ke server cPanel via WinSCP..." -ForegroundColor Green
    & $WinScpPath /script="$tmpScript"
    if ($LASTEXITCODE -ne 0) {
        throw "WinSCP keluar dengan kode $LASTEXITCODE"
    }
    if ($proto -eq 'sftp' -and (Test-Path $sshKeyPem)) {
        Write-Host "[4/4] Membersihkan cache Laravel di server (php artisan optimize:clear)..." -ForegroundColor Green
        ssh -i "$sshKeyPem" -p $port -o StrictHostKeyChecking=no "$($cfg.username)@$($cfg.host)" "cd $beRemote && php artisan optimize:clear"
    }
    Write-Host ""
    Write-Host "DEPLOY SELESAI! Semua file BE & FE sudah sinkron dengan server." -ForegroundColor Green
} finally {
    if (Test-Path $tmpScript) {
        Remove-Item $tmpScript -Force
    }
}
