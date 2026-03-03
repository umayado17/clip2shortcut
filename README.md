# clip2shortcut

AIチャット(Claude/ChatGPT)の共有URLをワンクリックでショートカットファイル化。Win/Mac対応。

![clip2shortcut](clip2shortcut.png)

## 概要

クリップボードにコピーしたURLから、ページタイトルをファイル名にしたURLショートカット(.url)を
ワンクリックで作成するツール。Claude・ChatGPTの共有リンクはもちろん、一般のWebページにも対応。

ファイル名は「ページタイトル Share.url」の形式で作成される。

## 共通の動作仕様

### タイトル取得の優先順位

1. 共有URL検出（claude.ai/share/, chatgpt.com/share/）→ ブラウザのアクティブタブが元チャットページであれば、そのタイトルを使用
2. ブラウザの全タブからURL一致で検索（Edge → Chrome → Safari）
3. HTTP取得で og:title → title タグの順に取得（Cloudflareチャレンジページは自動除外）
4. 上記すべて失敗した場合はダイアログで手入力（ドメイン名を初期値として表示）

### ファイル作成

- クリップボードからURLを取得
- 上記の優先順位でページタイトルを取得
- タイトルから「 - Claude」「 - ChatGPT」等のサフィックスを自動除去
- ファイル名末尾に「 Share」を付加
- ファイル名に使えない文字はアンダースコアに置換
- 同名ファイルが存在する場合は連番を付加
- 保存先はファイラーで開いているカレントフォルダ（取得できない場合はデスクトップ）

## 使用例

- https://www.yahoo.co.jp/ → 「Yahoo! JAPAN Share.url」
- https://claude.ai/share/xxxx → Claudeのチャットタイトルに基づいたファイル名

---

## Windows版

### ファイル構成

| ファイル | 説明 |
|---------|------|
| install_win.ps1 | インストーラー（管理者PowerShellで実行） |
| CreateUrlShortcut.ps1 | メインスクリプト（BOM付きUTF-8） |
| AddContextMenu.reg | 右クリックメニュー登録（手動登録用、BOM付きUTF-8） |
| RemoveContextMenu.reg | 右クリックメニュー削除（アンインストール用） |

### セットアップ手順

**方法1: インストーラーで自動セットアップ（推奨）**

全ファイルを同じフォルダに置き、管理者PowerShellで実行：
```powershell
.\install_win.ps1
```
スクリプトの C:\Tools\ への配置とレジストリ登録が自動で行われる。

**方法2: 手動セットアップ**

1. CreateUrlShortcut.ps1 を C:\Tools\ に保存する（別の場所に置く場合は AddContextMenu.reg 内のパスを書き換え）
2. AddContextMenu.reg をダブルクリック → 「はい」で登録

**3. 使い方**

1. ブラウザでURLをコピー（Ctrl+L → Ctrl+C）
2. エクスプローラーで保存したいフォルダを開く
3. 背景を右クリック → 「その他のオプションを確認」→「URLショートカット作成」
4. 「ページタイトル Share.url」ファイルが作成される

### Windows 11での注意事項

Windows 11では右クリックメニューが簡略化されているため、
本ツールは「その他のオプションを確認」内に表示される。
Shift + 右クリックで直接旧メニューを表示することも可能。

### アンインストール

1. RemoveContextMenu.reg をダブルクリック → 「はい」で削除
2. C:\Tools\CreateUrlShortcut.ps1 を手動で削除

### 技術メモ

- PowerShellスクリプトはBOM付きUTF-8で保存する必要がある
  （BOMなしの場合、Windows PowerShellがShift-JISとして読み込み日本語が文字化けする）
- regファイルも同様にBOM付きUTF-8で保存する必要がある
- レジストリの登録先: HKEY_CLASSES_ROOT\Directory\Background\shell\CreateUrlShortcut
- ショートカット形式: .url（Windowsインターネットショートカット）
- ブラウザタブのタイトル取得はEdgeのウィンドウタイトル（Get-Process）から取得

---

## Mac版

### ファイル構成

| ファイル | 説明 |
|---------|------|
| install_mac.sh | インストーラー |
| create_url_shortcut.sh | メインスクリプト（bash） |

### セットアップ手順

**方法1: インストーラーで自動セットアップ（推奨）**

全ファイルを同じフォルダに置き、ターミナルで実行：
```bash
bash install_mac.sh
```
スクリプトの ~/Tools/ への配置と、Automatorクイックアクション（.workflowファイル）の
~/Library/Services/ への配置が自動で行われる。Automatorの手動操作は不要。

**方法2: 手動セットアップ**

1. スクリプトを配置：
   ```bash
   mkdir -p ~/Tools
   cp create_url_shortcut.sh ~/Tools/
   chmod +x ~/Tools/create_url_shortcut.sh
   ```
2. Automatorでクイックアクション化：
   1. Automatorを開く → 「新規書類」→「クイックアクション」を選択
   2. 上部の設定: ワークフローが受け取る入力:「入力なし」、検索対象:「Finder.app」
   3. 左の検索欄で「シェル」→「シェルスクリプトを実行」をドラッグして追加
   4. シェル: /bin/bash、入力の引き渡し方法: stdinへ
   5. スクリプト欄に入力: ~/Tools/create_url_shortcut.sh
   6. Command+S で保存 → 名前を「URLショートカット作成」

**3. 使い方**

1. ブラウザでURLをコピー
2. Finderで保存したいフォルダを開く
3. 右クリック → 「クイックアクション」→「URLショートカット作成」
4. 「ページタイトル Share.url」ファイルが作成される

### キーボードショートカットの割り当て（任意）

1. システム設定 → キーボード → キーボードショートカット → サービス
2. 「URLショートカット作成」を見つけてショートカットキーを割り当て（例: Command+Option+U）

### アンインストール

1. ~/Library/Services/URLショートカット作成.workflow を削除
2. ~/Tools/create_url_shortcut.sh を削除

### 技術メモ

- ショートカット形式: .url（Windows互換形式、macOSでも開ける）
- Finderの最前面ウィンドウのフォルダをAppleScriptで取得
- ブラウザタブのタイトル取得はAppleScriptでEdge/Chrome/Safariに対応
- ページタイトルのHTTPフォールバックはcurlで取得し、sedでHTMLエンティティをデコード
- インストーラーはAutomatorの .workflow ファイル（Info.plist + document.wflow）を直接生成して ~/Library/Services/ に配置する。Automatorの手動操作は不要

---

## 作者

**平岡憲人 (Norito Hiraoka)**
清風情報工科学院 専務理事・校長
GitHub: [@umayado17](https://github.com/umayado17)

## ライセンス

MIT License — 詳細は [LICENSE](LICENSE) を参照。