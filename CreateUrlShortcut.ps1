# CreateUrlShortcut.ps1
# Clipboard URL -> Get page title -> Create .url shortcut

param(
    [string]$TargetFolder = ""
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Web

# --- Get URL from clipboard ---
$Url = [System.Windows.Forms.Clipboard]::GetText()

if ([string]::IsNullOrWhiteSpace($Url)) {
    [System.Windows.Forms.MessageBox]::Show(
        "クリップボードにURLがありません。`nURLをコピーしてから再実行してください。",
        "URLショートカット作成",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    exit
}

if ($Url -notmatch '^https?://') {
    [System.Windows.Forms.MessageBox]::Show(
        "クリップボードの内容がURLではありません。",
        "URLショートカット作成",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    exit
}

# --- Get page title ---
$PageTitle = ""

# Method 0: Share URL (claude.ai/share/, chatgpt.com/share/) -> Get active tab title from browser
if ($Url -match 'claude\.ai/share/' -or $Url -match 'chatgpt\.com/share/') {
    if ($Url -match 'claude\.ai/') {
        $ChatUrlPattern = "claude.ai/chat/"
    } else {
        $ChatUrlPattern = "chatgpt.com/c/"
    }

    # Try Microsoft Edge
    if ([string]::IsNullOrWhiteSpace($PageTitle)) {
        try {
            $Edge = [System.Runtime.InteropServices.Marshal]::GetActiveObject("Microsoft Edge")
        } catch {}
    }

    # Use UI Automation to get Edge active tab title
    if ([string]::IsNullOrWhiteSpace($PageTitle)) {
        try {
            $EdgeProcesses = Get-Process -Name "msedge" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -ne "" }
            foreach ($proc in $EdgeProcesses) {
                $title = $proc.MainWindowTitle
                if ($title -and $title -ne "") {
                    # Edge window title format: "Page Title - Microsoft Edge"
                    # or "Page Title and target URL"
                    $PageTitle = $title -replace ' - Microsoft Edge$', '' -replace ' - Google Chrome$', ''
                    break
                }
            }
        } catch {}
    }

    # Verify: if we got a title but it doesn't seem related, clear it
    # (Edge main window title should be the active tab)
}

# Method 1: Curl with og:title priority and Cloudflare filter
if ([string]::IsNullOrWhiteSpace($PageTitle)) {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $Response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        $Html = $Response.Content

        # Try og:title first
        if ($Html -match '<meta property="og:title" content="([^"]*)"') {
            $PageTitle = $Matches[1].Trim()
        }
        # Fallback to title tag
        if ([string]::IsNullOrWhiteSpace($PageTitle) -and $Html -match '<title[^>]*>(.*?)</title>') {
            $PageTitle = $Matches[1].Trim()
        }
        # Decode HTML entities
        if (-not [string]::IsNullOrWhiteSpace($PageTitle)) {
            $PageTitle = [System.Web.HttpUtility]::HtmlDecode($PageTitle)
        }
        # Filter Cloudflare challenge pages
        if ($PageTitle -match '^Just a moment' -or $PageTitle -match '^Attention Required' -or $PageTitle -match '^Please Wait') {
            $PageTitle = ""
        }
    }
    catch {
        # Title fetch failed
    }
}

# Remove browser/service suffix from title
if (-not [string]::IsNullOrWhiteSpace($PageTitle)) {
    $PageTitle = $PageTitle -replace ' - Claude$', '' -replace ' - ChatGPT$', '' -replace ' \| Claude$', '' -replace ' \| ChatGPT$', '' -replace ' - Microsoft Edge$', '' -replace ' - Google Chrome$', ''
}

# Method 2: Dialog for manual input
if ([string]::IsNullOrWhiteSpace($PageTitle)) {
    try {
        $DefaultName = ([System.Uri]::new($Url)).Host
    } catch {
        $DefaultName = "shortcut"
    }
    Add-Type -AssemblyName Microsoft.VisualBasic
    $PageTitle = [Microsoft.VisualBasic.Interaction]::InputBox(
        "ページタイトルを自動取得できませんでした。`nショートカットの名前を入力してください。`n`nURL: $Url",
        "URLショートカット作成",
        $DefaultName
    )
    if ([string]::IsNullOrWhiteSpace($PageTitle)) {
        exit
    }
}

# --- Sanitize filename ---
$FileName = $PageTitle -replace '[\\/:*?"<>|]', '_'
if ($FileName.Length -gt 200) {
    $FileName = $FileName.Substring(0, 200)
}
$FileName = $FileName.Trim() + " Share"

# --- Determine save folder ---
if ([string]::IsNullOrWhiteSpace($TargetFolder)) {
    $TargetFolder = [Environment]::GetFolderPath("Desktop")
}

# --- Avoid duplicates ---
$FilePath = Join-Path $TargetFolder "$FileName.url"
$Counter = 1
while (Test-Path $FilePath) {
    $FilePath = Join-Path $TargetFolder "$FileName ($Counter).url"
    $Counter++
}

# --- Create .url file ---
$Content = @"
[InternetShortcut]
URL=$Url
"@

try {
    [System.IO.File]::WriteAllText($FilePath, $Content, [System.Text.Encoding]::UTF8)
    [System.Windows.Forms.MessageBox]::Show(
        "作成しました。`n`n$FileName.url",
        "URLショートカット作成",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
}
catch {
    [System.Windows.Forms.MessageBox]::Show(
        "作成に失敗しました。`n$($_.Exception.Message)",
        "URLショートカット作成",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
}