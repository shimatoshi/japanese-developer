#!/usr/bin/env bash
# SessionStart hook: 起動時プライマー情報を収集してコンテキストに注入
input=$(cat)

PRIMER_PATH="$HOME/.gemini/primer.md"

if [ ! -f "$PRIMER_PATH" ]; then
  echo '{"hookSpecificOutput": {"additionalContext": ""}}'
  exit 0
fi

# --- git連携情報を収集 ---
git_info=""
if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
  git_user=$(git config user.name 2>/dev/null || echo "未設定")
  git_email=$(git config user.email 2>/dev/null || echo "未設定")
  git_branch=$(git branch --show-current 2>/dev/null || echo "不明")
  git_remote=$(git remote -v 2>/dev/null | head -1 | awk '{print $2}' || echo "なし")
  git_status_count=$(git status --short 2>/dev/null | wc -l | tr -d ' ')

  git_info="現在のgit情報:
- ユーザー: ${git_user} <${git_email}>
- ブランチ: ${git_branch}
- リモート: ${git_remote}
- 未コミット変更: ${git_status_count}件"
else
  git_info="（現在のディレクトリはgitリポジトリではありません）"
fi

# --- カスタムコマンド一覧を収集 ---
custom_commands=""
commands_dir="$HOME/.gemini/commands"
if [ -d "$commands_dir" ]; then
  for cmd_file in "$commands_dir"/*.md; do
    [ -f "$cmd_file" ] || continue
    cmd_name=$(basename "$cmd_file" .md)
    # ファイル1行目から説明を取得
    cmd_desc=$(head -1 "$cmd_file" | sed 's/^#* *//')
    custom_commands="${custom_commands}
- \`/${cmd_name}\` — ${cmd_desc}"
  done
fi

if [ -z "$custom_commands" ]; then
  custom_commands="（カスタムコマンドなし）"
fi

# --- テンプレートに動的情報を埋め込み ---
primer_content=$(cat "$PRIMER_PATH")
primer_content="${primer_content//\{\{GIT_INFO\}\}/$git_info}"
primer_content="${primer_content//\{\{CUSTOM_COMMANDS\}\}/$custom_commands}"

# --- ターミナルにメニュー表示（stderrで直接ユーザーに見せる） ---
{
  echo ""
  echo "━━━ japanese-developer プライマー ━━━"
  echo ""
  echo "  1. Termuxとは？     — スマホの中のキッチン"
  echo "  2. gitとは？        — セーブデータ管理"
  echo "  3. Gemini CLIとは？ — AIの助手"
  echo "  4. エージェントとは？— 腕のいい助手"
  echo "  5. 連絡先           — shimadatoshiyuki839@gmail.com"
  if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    echo "  6. git連携          — ${git_branch} @ $(basename "${git_remote%.git}" 2>/dev/null || echo '-')"
  else
    echo "  6. git連携          — (リポジトリ外)"
  fi
  echo "  7. コマンド一覧     — setup / status / error 等"
  echo "  8. 視覚設定         — UDフォント・文字サイズ"
  echo ""
  echo "  詳しく知りたい項目の番号を伝えてください。"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
} >&2

# --- JSON出力（改行をエスケープ） ---
escaped=$(printf '%s' "$primer_content" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')

cat <<EOF
{
  "hookSpecificOutput": {
    "additionalContext": ${escaped}
  }
}
EOF
exit 0
