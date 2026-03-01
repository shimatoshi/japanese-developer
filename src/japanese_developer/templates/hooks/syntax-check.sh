#!/data/data/com.termux/files/usr/bin/bash
# AfterTool hook: コード生成後の構文エラー自動チェック
# write_file/edit_file の後に実行され、構文エラーがあればGeminiに報告する

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# ファイル書き込み系ツールのみ対象
case "$TOOL_NAME" in
  write_file|edit_file|create_file|replace_in_file|write_to_file)
    ;;
  *)
    exit 0
    ;;
esac

# 書き込まれたファイルパスを取得
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.path // .tool_input.file_path // .tool_input.target_file // empty')

if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# 拡張子で判定
EXT="${FILE_PATH##*.}"
ERRORS=""

case "$EXT" in
  py)
    ERRORS=$(/data/data/com.termux/files/usr/bin/python3 -m py_compile "$FILE_PATH" 2>&1)
    ;;
  js|mjs)
    ERRORS=$(/data/data/com.termux/files/usr/bin/node --check "$FILE_PATH" 2>&1)
    ;;
  ts|tsx|jsx)
    # npx tscは遅いのでesbuildで簡易チェック
    if command -v npx &>/dev/null && [ -f "$(dirname "$FILE_PATH")/node_modules/.bin/tsc" ]; then
      ERRORS=$(cd "$(dirname "$FILE_PATH")" && npx tsc --noEmit --pretty false "$FILE_PATH" 2>&1 | head -20)
    elif command -v node &>/dev/null; then
      # tscがなければnodeで基本的な構文チェック（JSとして）
      ERRORS=$(/data/data/com.termux/files/usr/bin/node --check "$FILE_PATH" 2>&1)
    fi
    ;;
  json)
    ERRORS=$(/data/data/com.termux/files/usr/bin/python3 -m json.tool "$FILE_PATH" >/dev/null 2>&1 && echo "" || echo "JSON構文エラー: $FILE_PATH")
    if [ -z "$ERRORS" ]; then
      ERRORS=""
    fi
    ;;
  sh|bash)
    ERRORS=$(/data/data/com.termux/files/usr/bin/bash -n "$FILE_PATH" 2>&1)
    ;;
  html|htm)
    # 閉じタグの不一致を簡易チェック
    OPEN=$(/data/data/com.termux/files/usr/bin/grep -cE '<(div|span|p|section|article|main|header|footer|nav|ul|ol|li|table|tr|td|th|form|button|a|h[1-6])[^/]*>' "$FILE_PATH" 2>/dev/null || echo 0)
    CLOSE=$(/data/data/com.termux/files/usr/bin/grep -cE '</(div|span|p|section|article|main|header|footer|nav|ul|ol|li|table|tr|td|th|form|button|a|h[1-6])>' "$FILE_PATH" 2>/dev/null || echo 0)
    if [ "$OPEN" != "$CLOSE" ]; then
      ERRORS="HTML警告: 開きタグ(${OPEN})と閉じタグ(${CLOSE})の数が一致しません"
    fi
    ;;
  css|scss)
    # 括弧の対応チェック
    OPEN=$(/data/data/com.termux/files/usr/bin/grep -o '{' "$FILE_PATH" 2>/dev/null | wc -l)
    CLOSE=$(/data/data/com.termux/files/usr/bin/grep -o '}' "$FILE_PATH" 2>/dev/null | wc -l)
    if [ "$OPEN" != "$CLOSE" ]; then
      ERRORS="CSS構文エラー: { (${OPEN}個) と } (${CLOSE}個) の数が一致しません"
    fi
    ;;
esac

# エラーがあればGeminiに報告
if [ -n "$ERRORS" ]; then
  # JSON安全にエスケープ
  ESCAPED=$(echo "$ERRORS" | /data/data/com.termux/files/usr/bin/python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))")
  echo "{\"systemMessage\": \"構文エラー検出 [${FILE_PATH}]: ${ESCAPED}。このエラーを修正してください。\"}" >&2
fi

exit 0
