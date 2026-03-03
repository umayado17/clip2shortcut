# URLショートカット作成ツール 開発記録

作成日: 2026年3月3日

## 目的

Claudeのチャット共有URL等をクリップボードからワンクリックでショートカットファイル化し、
Google Drive等で整理・管理できるようにする。

## 試行錯誤の経緯

### 1. Windows版の基本実装

**やったこと:** PowerShellスクリプトで、クリップボードのURLからページタイトルを取得し .url ファイルを作成。エクスプローラーの右クリックメニュー（レジストリ登録）から呼び出す方式にした。

**問題1: スクリプトが動かない — 日本語変数名の文字化け**

PowerShellスクリプト内の日本語変数名・メッセージが文字化けしてパースエラーになった。
原因はWindows PowerShellがスクリプトをShift-JIS（CP932）として読み込むため。

→ 解決: 変数名を英語に変更し、スクリプトをBOM付きUTF-8で保存。BOM（EF BB BF）があればPowerShellはUTF-8として認識する。

**問題2: レジストリの日本語メニュー名が文字化け**

.regファイル内の日本語パラメータ名（-保存先フォルダ）が化けて、カレントフォルダのパスがスクリプトに渡らなかった。

→ 解決: .regファイルもBOM付きUTF-8で作成。レジストリエディタで直接値を修正して動作確認。

**教訓: WindowsでPowerShellスクリプトやregファイルに日本語を含める場合、BOM付きUTF-8は必須。**

### 2. Windows 11の右クリックメニュー問題

**やったこと:** `HKEY_CLASSES_ROOT\Directory\Background\shell` にメニュー項目を登録。

**問題3: Windows 11の新しい右クリックメニューに表示されない**

Windows 11ではコンテキストメニューが簡略化されており、従来のshell登録は「その他のオプションを確認」内にしか表示されない。

**試したこと:**
- `ShowBasedOnVelocityId` レジストリ値の追加 → 効果なし
- `.url` 拡張子の `ShellNew\Command` 登録で「新規作成」メニューに追加を試みる → Windows 11では正しく関連付けされたプログラムと拡張子の登録が必要で、単純な追加では表示されなかった

→ 結論: Windows 11の新メニューへの直接追加は制約が厳しく断念。「その他のオプション」（Shift+右クリックで直接表示可能）での運用とした。

**教訓: Windows 11の新コンテキストメニューへのカスタム項目追加は、COMオブジェクト登録等の複雑な手順が必要。コスト対効果を見て判断すべき。**

### 3. Mac版の実装

**やったこと:** bashスクリプトで同等機能を実装。Automatorのクイックアクションとして登録し、Finderの右クリックメニューから呼び出せるようにした。

**問題なし:** Mac版はスムーズに実装完了。Finderの最前面ウィンドウのフォルダをAppleScriptで取得する方式も問題なく動作。

### 4. Cloudflare保護サイトのタイトル取得問題

**問題4: Claudeの共有URLで「Just a moment... Share.webloc」が作成される**

claude.aiにcurl/Invoke-WebRequestでアクセスすると、Cloudflareのチャレンジページが返される。そのページのtitleタグが「Just a moment...」であり、本来のページタイトルが取得できなかった。

**試したこと:**
- og:titleメタタグの優先取得 → Cloudflareページにはog:titleが存在しないため効果なし
- ブラウザのタブからタイトル取得 → 共有URLのページはブラウザで開かれていないため取得不可

**問題5: 共有URLがブラウザのタブに存在しない**

Claudeの共有機能は、チャットページ（`claude.ai/chat/xxxx`）上にモーダルダイアログとして表示されるだけで、ブラウザが `claude.ai/share/yyyy` に遷移するわけではない。したがってブラウザのタブにはshare URLが存在しない。

**問題6: chatとshareのIDが異なる**

`claude.ai/chat/c79cdafc-...` と `claude.ai/share/4bc13be4-...` のように、チャットIDと共有IDは別物。セキュリティ上の理由と推測される。IDの一致でタブを検索する方法は使えない。

→ 解決: **「共有操作中のブラウザのアクティブタブ」に着目。** 共有URLをコピーする瞬間、ブラウザのアクティブタブは必ず元のチャットページ（`claude.ai/chat/...`）である。したがって、クリップボードのURLが `claude.ai/share/` を含む場合、ブラウザのアクティブタブのURLが `claude.ai/chat/` であれば、そのタブのタイトルを使用する。ChatGPT（`chatgpt.com/share/` → `chatgpt.com/c/`）も同じロジックで対応。

**教訓: IDや完全一致に頼らず、「ユーザーの操作文脈」（＝共有操作中ならアクティブタブが元ページ）を利用することで、技術的制約を回避できる。**

### 5. タイトル取得の最終設計

最終的に4段階のフォールバック構造となった:

1. 共有URL検出 → ブラウザのアクティブタブタイトル取得
2. ブラウザの全タブからURL部分一致検索（Edge → Chrome → Safari）
3. HTTP取得（og:title → title、Cloudflareページは除外）
4. ダイアログで手入力（ドメイン名を初期値として表示）

## 得られた技術的知見

| 領域 | 知見 |
|------|------|
| Windows PowerShell | 日本語を含むスクリプトはBOM付きUTF-8必須 |
| Windows レジストリ | .regファイルもBOM付きUTF-8で作成すること |
| Windows 11 | 新コンテキストメニューへのカスタム追加は困難。Shift+右クリックで旧メニュー表示可能 |
| macOS Automator | クイックアクションでFinderの右クリックに統合可能 |
| macOS AppleScript | Edge/Chrome/Safariのタブ情報にアクセス可能（プロセス存在確認後） |
| Cloudflare | curl等の非ブラウザアクセスではチャレンジページが返される。titleは「Just a moment...」 |
| Claude共有URL | chat IDとshare IDは異なる。共有はモーダル表示でページ遷移しない |
| 設計思想 | 技術的制約に直面したとき、ユーザーの操作文脈（行動パターン）を利用して回避できることがある |
| ファイル形式 | .url形式はWindows/macOS両方で開けるため、.weblocではなく.urlに統一するのが合理的 |
| macOS Automator | .workflowファイル（Info.plist + document.wflow）を直接生成して ~/Library/Services/ に配置すれば、Automatorの手動操作なしでクイックアクションを登録できる |
| Windows インストール | PowerShellからレジストリに直接書き込めば、.regファイルの文字化け問題を回避できる。ただし管理者権限が必要 |

## 最終成果物

| ファイル | OS | 説明 |
|---------|-----|------|
| install_win.ps1 | Win | インストーラー（スクリプト配置+レジストリ登録） |
| CreateUrlShortcut.ps1 | Win | メインスクリプト |
| AddContextMenu.reg | Win | 右クリックメニュー登録（手動登録用） |
| RemoveContextMenu.reg | Win | アンインストール用 |
| install_mac.sh | Mac | インストーラー（スクリプト配置+ワークフロー作成） |
| create_url_shortcut.sh | Mac | メインスクリプト |
| README_URLショートカット作成ツール.md | 共通 | セットアップ手順・仕様書 |
| 開発記録_URLショートカット作成ツール.md | 共通 | 試行錯誤の記録 |