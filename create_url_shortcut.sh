#!/bin/bash
# create_url_shortcut.sh
# クリップボードのURLからページタイトルを取得し、.weblocショートカットを作成する

# --- クリップボードからURL取得 ---
URL=$(pbpaste)

if [ -z "$URL" ]; then
    osascript -e 'display dialog "クリップボードにURLがありません。" buttons {"OK"} default button "OK" with icon caution with title "URLショートカット作成"'
    exit 1
fi

if [[ ! "$URL" =~ ^https?:// ]]; then
    osascript -e 'display dialog "クリップボードの内容がURLではありません。" buttons {"OK"} default button "OK" with icon caution with title "URLショートカット作成"'
    exit 1
fi

# --- ページタイトル取得 ---
PAGE_TITLE=""

# 方法0: 共有URL（claude.ai/share/, chatgpt.com/share/）の場合、
#         ブラウザのアクティブタブから元チャットのタイトルを取得
if [[ "$URL" == *"claude.ai/share/"* ]] || [[ "$URL" == *"chatgpt.com/share/"* ]]; then
    # 共有元のドメインを特定
    if [[ "$URL" == *"claude.ai/"* ]]; then
        CHAT_URL_PATTERN="claude.ai/chat/"
    else
        CHAT_URL_PATTERN="chatgpt.com/c/"
    fi

    # Microsoft Edge のアクティブタブを確認
    if [ -z "$PAGE_TITLE" ]; then
        PAGE_TITLE=$(osascript -e "
        tell application \"System Events\"
            if exists (process \"Microsoft Edge\") then
                tell application \"Microsoft Edge\"
                    set activeUrl to URL of active tab of front window
                    if activeUrl contains \"$CHAT_URL_PATTERN\" then
                        return title of active tab of front window
                    end if
                end tell
            end if
        end tell
        return \"\"
        " 2>/dev/null)
    fi

    # Google Chrome のアクティブタブを確認
    if [ -z "$PAGE_TITLE" ]; then
        PAGE_TITLE=$(osascript -e "
        tell application \"System Events\"
            if exists (process \"Google Chrome\") then
                tell application \"Google Chrome\"
                    set activeUrl to URL of active tab of front window
                    if activeUrl contains \"$CHAT_URL_PATTERN\" then
                        return title of active tab of front window
                    end if
                end tell
            end if
        end tell
        return \"\"
        " 2>/dev/null)
    fi

    # Safari のアクティブタブを確認
    if [ -z "$PAGE_TITLE" ]; then
        PAGE_TITLE=$(osascript -e "
        tell application \"System Events\"
            if exists (process \"Safari\") then
                tell application \"Safari\"
                    set activeUrl to URL of current tab of front window
                    if activeUrl contains \"$CHAT_URL_PATTERN\" then
                        return name of current tab of front window
                    end if
                end tell
            end if
        end tell
        return \"\"
        " 2>/dev/null)
    fi
fi

# 方法1: ブラウザで開いているタブからタイトル取得（URL ID部分一致）
# URLからID部分を抽出
URL_ID=$(echo "$URL" | sed 's|.*/||')

# Microsoft Edge から取得を試みる
if [ -z "$PAGE_TITLE" ]; then
    PAGE_TITLE=$(osascript -e "
    tell application \"System Events\"
        if exists (process \"Microsoft Edge\") then
            tell application \"Microsoft Edge\"
                repeat with w in windows
                    repeat with t in tabs of w
                        if URL of t contains \"$URL_ID\" then
                            return title of t
                        end if
                    end repeat
                end repeat
            end tell
        end if
    end tell
    return \"\"
    " 2>/dev/null)
fi

# Google Chrome から取得を試みる
if [ -z "$PAGE_TITLE" ]; then
    PAGE_TITLE=$(osascript -e "
    tell application \"System Events\"
        if exists (process \"Google Chrome\") then
            tell application \"Google Chrome\"
                repeat with w in windows
                    repeat with t in tabs of w
                        if URL of t contains \"$URL_ID\" then
                            return title of t
                        end if
                    end repeat
                end repeat
            end tell
        end if
    end tell
    return \"\"
    " 2>/dev/null)
fi

# Safari から取得を試みる
if [ -z "$PAGE_TITLE" ]; then
    PAGE_TITLE=$(osascript -e "
    tell application \"System Events\"
        if exists (process \"Safari\") then
            tell application \"Safari\"
                repeat with w in windows
                    repeat with t in tabs of w
                        if URL of t contains \"$URL_ID\" then
                            return name of t
                        end if
                    end repeat
                end repeat
            end tell
        end if
    end tell
    return \"\"
    " 2>/dev/null)
fi

# 方法2: curlでHTMLから取得（フォールバック）
if [ -z "$PAGE_TITLE" ]; then
    HTML=$(curl -sL --max-time 10 "$URL" 2>/dev/null)
    # og:titleを優先
    PAGE_TITLE=$(echo "$HTML" | tr '\n' ' ' | sed -n 's/.*<meta property="og:title" content="\([^"]*\)".*/\1/p' | head -1)
    # og:titleがなければtitleタグから取得
    if [ -z "$PAGE_TITLE" ]; then
        PAGE_TITLE=$(echo "$HTML" | tr '\n' ' ' | sed -n 's/.*<title[^>]*>\([^<]*\)<\/title>.*/\1/p' | head -1)
    fi
    # Cloudflareページタイトルを除外
    if [[ "$PAGE_TITLE" == "Just a moment"* ]] || [[ "$PAGE_TITLE" == "Attention Required"* ]] || [[ "$PAGE_TITLE" == "Please Wait"* ]]; then
        PAGE_TITLE=""
    fi
fi

# HTMLエンティティの基本的なデコード
if [ -n "$PAGE_TITLE" ]; then
    PAGE_TITLE=$(echo "$PAGE_TITLE" | sed 's/&amp;/\&/g; s/&lt;/</g; s/&gt;/>/g; s/&quot;/"/g; s/&#39;/'"'"'/g; s/&#x27;/'"'"'/g')
fi

# ブラウザタイトルに " - Claude" " - ChatGPT" 等のサフィックスがあれば除去
if [ -n "$PAGE_TITLE" ]; then
    PAGE_TITLE=$(echo "$PAGE_TITLE" | sed 's/ - Claude$//; s/ - ChatGPT$//; s/ | Claude$//; s/ | ChatGPT$//')
fi

# 方法3: タイトル取得できなかった場合、ダイアログで手入力
if [ -z "$PAGE_TITLE" ]; then
    # ドメイン名を初期値として提示
    DEFAULT_NAME=$(echo "$URL" | sed -E 's|https?://||; s|/.*||')
    PAGE_TITLE=$(osascript -e "
    set dialogResult to display dialog \"ページタイトルを自動取得できませんでした。\" & return & \"ショートカットの名前を入力してください。\" & return & return & \"URL: $URL\" default answer \"$DEFAULT_NAME\" buttons {\"キャンセル\", \"OK\"} default button \"OK\" with title \"URLショートカット作成\"
    return text returned of dialogResult
    " 2>/dev/null)
    # キャンセルされた場合は終了
    if [ $? -ne 0 ] || [ -z "$PAGE_TITLE" ]; then
        exit 0
    fi
fi

# --- ファイル名サニタイズ ---
FILE_NAME=$(echo "$PAGE_TITLE" | sed 's/[\\/:*?"<>|]/_/g' | cut -c1-200 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
FILE_NAME="${FILE_NAME} Share"

# --- 保存先（Finderの最前面フォルダ、なければデスクトップ）---
TARGET_FOLDER=$(osascript -e '
tell application "Finder"
    try
        set frontWin to target of front Finder window
        return POSIX path of (frontWin as alias)
    on error
        return POSIX path of (path to desktop)
    end try
end tell' 2>/dev/null)

if [ -z "$TARGET_FOLDER" ]; then
    TARGET_FOLDER="$HOME/Desktop"
fi

# --- 重複チェック ---
FILE_PATH="${TARGET_FOLDER}${FILE_NAME}.url"
COUNTER=1
while [ -e "$FILE_PATH" ]; do
    FILE_PATH="${TARGET_FOLDER}${FILE_NAME} (${COUNTER}).url"
    COUNTER=$((COUNTER + 1))
done

# --- .urlファイル作成（Windows互換形式） ---
cat > "$FILE_PATH" << URLFILE
[InternetShortcut]
URL=${URL}
URLFILE

if [ $? -eq 0 ]; then
    osascript -e "display dialog \"作成しました。\n\n$(basename "$FILE_PATH")\" buttons {\"OK\"} default button \"OK\" with icon note with title \"URLショートカット作成\""
else
    osascript -e 'display dialog "作成に失敗しました。" buttons {"OK"} default button "OK" with icon stop with title "URLショートカット作成"'
fi