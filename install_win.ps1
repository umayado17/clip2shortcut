# install_win.ps1
# URLショートカット作成ツール Windows版インストーラー
# 管理者PowerShellから実行してください

Write-Host "=== URLショートカット作成ツール インストール ===" -ForegroundColor Cyan
Write-Host ""

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# --- 1. スクリプト配置 ---
Write-Host "[1/3] スクリプトを C:\Tools\ に配置..."
if (-not (Test-Path "C:\Tools")) {
    New-Item -ItemType Directory -Path "C:\Tools" -Force | Out-Null
}
Copy-Item (Join-Path $ScriptDir "CreateUrlShortcut.ps1") "C:\Tools\CreateUrlShortcut.ps1" -Force
Write-Host "  -> C:\Tools\CreateUrlShortcut.ps1 を配置しました" -ForegroundColor Green

# --- 2. レジストリ登録 ---
Write-Host "[2/3] 右クリックメニューを登録..."
try {
    $regPath = "Registry::HKEY_CLASSES_ROOT\Directory\Background\shell\CreateUrlShortcut"
    $cmdPath = "Registry::HKEY_CLASSES_ROOT\Directory\Background\shell\CreateUrlShortcut\command"

    New-Item -Path $regPath -Force | Out-Null
    Set-ItemProperty -Path $regPath -Name "(Default)" -Value "URLショートカット作成"
    Set-ItemProperty -Path $regPath -Name "Icon" -Value "shell32.dll,14"

    New-Item -Path $cmdPath -Force | Out-Null
    Set-ItemProperty -Path $cmdPath -Name "(Default)" -Value 'powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\Tools\CreateUrlShortcut.ps1" -TargetFolder "%V"'

    Write-Host "  -> レジストリに登録しました" -ForegroundColor Green
}
catch {
    Write-Host "  -> レジストリ登録に失敗しました。管理者権限で再実行してください。" -ForegroundColor Red
    Write-Host "  エラー: $($_.Exception.Message)" -ForegroundColor Red
}

# --- 3. 完了 ---
Write-Host "[3/3] インストール完了" -ForegroundColor Cyan
Write-Host ""
Write-Host "使い方:"
Write-Host "  1. ブラウザでURLをコピー"
Write-Host "  2. エクスプローラーで保存先フォルダを開く"
Write-Host "  3. 右クリック → その他のオプション → URLショートカット作成"
Write-Host "     (Shift+右クリックで直接表示も可能)"
Write-Host ""
Write-Host "Enterキーで終了..." -ForegroundColor Gray
Read-Host
