<div align="center">

<img src="./App/AppIcon-1024.png" width="96" alt="English Paper Reader icon" />

# English Paper Reader

**英語論文を読みながら単語を登録し、そのまま復習できる macOS ネイティブアプリ**

[![Swift](https://img.shields.io/badge/Swift-6-FA7343?logo=swift&logoColor=white)](https://swift.org)
[![Platform](https://img.shields.io/badge/macOS-13+-000000?logo=apple)](https://developer.apple.com/macos/)
[![App](https://img.shields.io/badge/App-SwiftUI%20%2B%20PDFKit-blue)](#)
[![Release](https://img.shields.io/badge/release-GitHub-lightgrey)](https://github.com/mksmkss/English-Paper/releases)

[English](./README.en.md) | **日本語**

</div>

---

## 何ができるか

English Paper Reader は、英語論文 PDF を読みながら気になった単語をその場で登録し、意味・例文・出現箇所をあとから見返せる macOS アプリです。

- PDF を読みながら単語を選択して簡易登録
- 登録した単語を PDF 上でハイライト表示
- ホバーで意味や例文を確認
- フォルダで PDF を整理
- 下部の単語一覧から Definition ベースで検索
- appearance から論文中の該当位置へジャンプ
- 語彙データだけを GitHub に同期

---

## ダウンロード

### ワンライナーでインストール

```bash
curl -fsSL https://raw.githubusercontent.com/mksmkss/English-Paper/main/install.sh | sh
```

このスクリプトは次を行います。

- 最新 release の `PapersApp-macOS.zip` をダウンロード
- `/Applications/PapersApp.app` にインストール
- `~/Library/Application Support/EnglishPaperReader` をデータ保存先として利用

### 手動ダウンロード

```bash
curl -fL https://github.com/mksmkss/English-Paper/releases/latest/download/PapersApp-macOS.zip -o PapersApp-macOS.zip
```

その後、ZIP を展開して `PapersApp.app` を `/Applications` に移動してください。

> [!NOTE]
> `releases/latest/download/...` が使えるのは、GitHub Release が 1 回以上作成されたあとです。

---

## 主な機能

| 機能 | 説明 |
|------|------|
| 📄 **PDF 読書** | 論文 PDF を読みながらそのまま単語学習できる |
| ✍️ **Quick Register** | 単語を選択して意味をすぐ登録できる |
| 💡 **ホバー確認** | 登録済み単語にカーソルを止めると意味や例文が出る |
| 🟨 **ハイライト表示** | 登録済み appearance を PDF 上に表示 |
| 🗂 **フォルダ整理** | フォルダ作成、rename、ネスト、ドラッグ移動に対応 |
| 🔎 **単語一覧検索** | Definition を含めて一覧から検索できる |
| 🔗 **appearance ジャンプ** | 単語詳細から論文中の出現場所へ戻れる |
| ☁️ **Data-only GitHub Sync** | `backup.sql` だけを GitHub に同期 |

---

## GitHub 同期について

このアプリの GitHub 同期は、**コードではなく語彙データだけ**を対象にしています。

同期されるもの:

- 単語
- meanings
- examples
- appearances
- フォルダ構造
- PDF の所属情報

同期されないもの:

- PDF ファイル本体
- アプリのソースコード

語彙データは `~/Library/Application Support/EnglishPaperReader/backup.sql` に保存され、GitHub にはそのファイルだけを push します。

> [!IMPORTANT]
> 別の Mac では PDF の絶対パスが変わるため、同期後に一部 PDF の `Relink` が必要になることがあります。

---

## 使い方

### 1. PDF を追加する

左サイドバー上部の `Add PDF` ボタンから論文 PDF を追加します。

### 2. 単語を登録する

PDF 上の単語や短いフレーズを選択すると `Quick Register` が開きます。

- Definition を入力
- 必要なら `Pronunciation or kana` を入力
- 保存するとハイライトされる

### 3. 復習する

- 下部の単語一覧で見返す
- 右 Inspector で meanings / examples / appearances を編集
- appearance をクリックして論文中の位置へ戻る

### 4. GitHub に同期する

右上の GitHub アイコンから repository URL を入力すると、語彙データ同期を接続できます。

---

## 保存場所

データは Application Support の中に保存されます。

```text
~/Library/Application Support/EnglishPaperReader/
├── app.db
└── backup.sql
```

---

## ビルドと起動

### 開発用

```bash
swift build
swift run EnglishPaperReader
```

### .app バンドル作成

```bash
./App/build-app.sh
open /Users/masataka/Coding/Swift/english-paper-reader/.build-release/PapersApp.app
```

### 配布用アーカイブ作成

```bash
./App/package-release.sh
```

作成されるファイル:

- `dist/PapersApp-macOS.zip`
- `dist/PapersApp.dmg`

---

## リリース方法

GitHub Actions の release workflow は通常 push では動かず、**`v*` タグ push** または **manual dispatch** で動きます。

例:

```bash
git tag v0.1.0
git push origin v0.1.0
```

これで Actions が走り、release asset が公開されます。

---

## プロジェクト構成

```text
English-Paper/
├── Sources/EnglishPaperReader/
│   ├── App/                    # SwiftUI UI と画面ロジック
│   ├── Database/               # SQLite bootstrap / migration
│   ├── Models/                 # データモデル
│   ├── Repositories/           # DB アクセス
│   ├── Support/                # パス、git sync、backup export など
│   └── Utilities/              # PDF 処理や補助ユーティリティ
├── Tests/EnglishPaperReaderTests/
├── App/                        # app bundle / release packaging scripts
├── docs/
└── install.sh
```

---

## 補足

> [!NOTE]
> - `swift build` / `swift test` はローカルの SwiftPM / Command Line Tools 状態に影響を受ける場合があります。
> - 配布確認は `./App/build-app.sh` の app bundle 経路で行うのがおすすめです。
