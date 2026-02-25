#!/usr/bin/env bash
# BeforeTool hook: 常駐サーバーのフォアグラウンド起動を阻止する
# 一時起動（起動→確認→停止パターン）は許可する
input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // .tool_input.content // ""')

# 常駐サーバーパターン（Vite等の開発サーバー = つけっぱなし前提）
persistent_patterns=(
  "npm run dev"
  "npm run serve"
  "npm start"
  "npx vite"
  "vite dev"
  "vite preview"
)

# 一般サーバーパターン（一時起動なら許可）
general_patterns=(
  "uvicorn "
  "flask run"
  "python.*server\.py"
  "python.*app\.py"
  "python -m http\.server"
  "node.*server"
  "php -S"
  "ruby.*server"
  "cargo run.*server"
)

# バックグラウンド実行（& や kill を含む一連のコマンド）なら許可
is_background() {
  echo "$command" | grep -qE '&\s*(&&|;|$)|nohup |&& *kill|&& *curl.*&& *kill'
}

# --- 常駐サーバーは常にブロック（バックグラウンドでもつけっぱなしになるため） ---
for pattern in "${persistent_patterns[@]}"; do
  if echo "$command" | grep -qiE "$pattern"; then
    cat <<BLOCK
{
  "decision": "deny",
  "reason": "常駐型開発サーバーの起動を検出しました。CLIが進行不能になるため直接起動は禁止です。",
  "systemMessage": "⛔ 開発サーバーブロック: ユーザーに「別のターミナルで起動してください」と伝えてください。コマンド: $command"
}
BLOCK
    exit 0
  fi
done

# --- 一般サーバーはバックグラウンド起動（確認→停止パターン）なら許可 ---
for pattern in "${general_patterns[@]}"; do
  if echo "$command" | grep -qiE "$pattern"; then
    if is_background; then
      echo "一時起動パターンを検出、許可" >&2
      echo '{"decision": "allow"}'
      exit 0
    fi

    cat <<BLOCK
{
  "decision": "deny",
  "reason": "サーバーのフォアグラウンド起動を検出しました。一時確認なら「起動 → curl → kill」のパターンで実行してください。",
  "systemMessage": "⛔ サーバー起動ブロック: フォアグラウンド起動は禁止です。一時確認は「python server.py & sleep 2 && curl ... && kill %1」のパターンで実行してください。コマンド: $command"
}
BLOCK
    exit 0
  fi
done

echo '{"decision": "allow"}'
exit 0
