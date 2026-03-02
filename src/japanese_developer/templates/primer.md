# japanese-developer プライマー

セッション開始時に、以下の情報をメニュー形式でユーザーに表示せよ。
装飾はシンプルに、番号付きで見やすく整形すること。

---

## 1. Termuxとは？

スマホの中にある「キッチン」のようなものです。
Node.jsやPythonは鍋や包丁のような調理道具で、gitは冷蔵庫（材料の保管と出し入れ）にあたります。
調理場に立っているだけなので、どんな道具を使って何を作るかはすべてあなた次第です。
PCがなくても、このキッチンだけで本格的なモノづくりができます。

## 2. gitとは？

作ったモノの「セーブデータ管理」です。
ファイルの変更履歴をすべて記録してくれるので、いつでも過去の状態に戻せます。
複数人で同時に作業しても、誰が何を変えたかすべて追えます。
`git add`（材料を並べる） → `git commit`（調理完了の記録） → `git push`（冷蔵庫に保存）が基本の流れです。

## 3. Gemini CLIとは？

Googleが作ったAIの助手です。このキッチンの中で一緒に作業してくれます。
「これ作って」と言えばコードを書きますし、「これ何？」と聞けば説明してくれます。
`~/.gemini/GEMINI.md` がこの助手への指示書です。hooksで動き方をカスタマイズできます。

## 4. コーディングエージェントとは？

AIがコードの読み書き・実行・デバッグまで自律的にやってくれる仕組みです。
「〇〇を作って」と言うだけで、ファイルを作成し、テストし、壊れていたら修正するところまでやります。
Gemini CLI、Claude Code、Cursor等がこれにあたります。
あなたがシェフで、エージェントは腕のいい助手です。指示を出すのがあなたの仕事です。

## 5. 無責任者連絡先

このツールに関する問い合わせ先（無保証・無責任）:
shimadatoshiyuki839@gmail.com

## 6. git連携

{{GIT_INFO}}

## 7. コマンド一覧

### japanese-developer コマンド
- `japanese-developer setup` — 環境セットアップ（hooks・GEMINI.md等を導入）
- `japanese-developer setup --force` — 既存ファイルを上書きして再セットアップ
- `japanese-developer status` — インストール状態の確認
- `japanese-developer error` — エラー診断レポート作成（対話形式）
- `japanese-developer error --auto` — 環境情報のみ自動収集
- `japanese-developer termux-setup` — Termux向けUI最適化
- `japanese-developer uninstall` — 導入したhookの削除

### Gemini カスタムコマンド
{{CUSTOM_COMMANDS}}

## 8. 視覚設定

Termuxの画面を見やすくするための設定です。

### フォント
UDフォント（ユニバーサルデザインフォント）を適用すると文字が読みやすくなります。
設定方法: フォントファイルを `~/.termux/font.ttf` に配置して `termux-reload-settings` を実行してください。

おすすめ:
- **BIZ UDゴシック** — 日本語の可読性が高い無料UDフォント
- **HackGen** — プログラミング向け。英数字と日本語のバランスが良い
- **PlemolJP** — HackGen系、IBM Plex Mono + IBM Plex Sans JP ベース

### 文字サイズ
- ピンチイン/ピンチアウトでその場で拡大縮小できます
- 固定したい場合は `~/.termux/termux.properties` に以下を追記してください:
  ```
  font-size=14
  ```
  （数値はお好みで。12〜16あたりが見やすいです）
- 設定後 `termux-reload-settings` で反映されます
