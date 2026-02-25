#!/usr/bin/env bash
# BeforeTool hook: サーバー起動コマンドを検出して阻止する
input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // .tool_input.content // ""')

# サーバー起動パターン（フォアグラウンド実行を検出）
server_patterns=(
  "uvicorn "
  "flask run"
  "python.*server\.py"
  "python.*app\.py"
  "python -m http\.server"
  "npm start"
  "npm run dev"
  "npm run serve"
  "node.*server"
  "php -S"
  "ruby.*server"
  "cargo run.*server"
)

for pattern in "${server_patterns[@]}"; do
  if echo "$command" | grep -qiE "$pattern"; then
    # nohup や & でバックグラウンド実行なら許可
    if echo "$command" | grep -qE '&\s*$|nohup '; then
      echo "バックグラウンド実行を検出、許可" >&2
      echo '{"decision": "allow"}'
      exit 0
    fi

    cat <<BLOCK
{
  "decision": "deny",
  "reason": "サーバー起動コマンドを検出しました。CLIが進行不能になるため、シェル内での直接起動は禁止されています。",
  "systemMessage": "⛔ サーバー起動ブロック: ユーザーに「別のターミナルで起動してください」と伝えてください。コマンド: $command"
}
BLOCK
    exit 0
  fi
done

echo '{"decision": "allow"}'
exit 0
