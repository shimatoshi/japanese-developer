#!/usr/bin/env bash
# SessionStart hook: 日本語での応答を強制するコンテキストを注入
input=$(cat)

cat <<'EOF'
{
  "hookSpecificOutput": {
    "additionalContext": "【最重要ルール】すべての応答・コメント・コミットメッセージ・説明を日本語で行うこと。英語での応答は禁止。コード中の変数名・関数名は英語可だが、それ以外はすべて日本語。"
  }
}
EOF
exit 0
