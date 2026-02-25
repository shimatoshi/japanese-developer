#!/usr/bin/env bash
# AfterTool hook: git commit 検出後に WORK_LOG.md へ自動追記
input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // ""')
command=$(echo "$input" | jq -r '.tool_input.command // .tool_input.content // ""')

# git commit コマンドかチェック
if ! echo "$command" | grep -qE '^git commit'; then
  echo '{}'
  exit 0
fi

# コミットが成功したかチェック（tool_responseにerrorがないか）
error=$(echo "$input" | jq -r '.tool_response.error // ""')
if [ -n "$error" ] && [ "$error" != "null" ]; then
  echo "コミット失敗のためログ記録をスキップ" >&2
  echo '{}'
  exit 0
fi

# プロジェクトディレクトリを取得
project_dir="${GEMINI_PROJECT_DIR:-$(pwd)}"
worklog="$project_dir/WORK_LOG.md"

# 最新コミット情報を取得
commit_hash=$(cd "$project_dir" && git log -1 --format="%h" 2>/dev/null)
commit_msg=$(cd "$project_dir" && git log -1 --format="%s" 2>/dev/null)
changed_files=$(cd "$project_dir" && git diff-tree --no-commit-id --name-only -r HEAD 2>/dev/null | head -10)
timestamp=$(date '+%Y-%m-%d %H:%M')

# WORK_LOG.md がなければヘッダー付きで作成
if [ ! -f "$worklog" ]; then
  cat > "$worklog" <<HEADER
# 作業ログ

このファイルは自動生成されます。各コミット時に作業内容が記録されます。

---

HEADER
  echo "WORK_LOG.md を新規作成" >&2
fi

# ログエントリを追記
cat >> "$worklog" <<ENTRY

## $timestamp

- **内容**: $commit_msg
- **変更ファイル**: $(echo "$changed_files" | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
- **コミット**: $commit_hash
ENTRY

echo "WORK_LOG.md にログを追記: $commit_hash" >&2

# 追加コンテキストとして通知
cat <<RESPONSE
{
  "hookSpecificOutput": {
    "additionalContext": "作業ログを WORK_LOG.md に記録しました ($commit_hash: $commit_msg)"
  }
}
RESPONSE
exit 0
