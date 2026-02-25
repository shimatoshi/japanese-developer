#!/usr/bin/env bash
# AfterTool hook: git commit 検出後にログを自動記録
# - logs/WORK_LOG.md（統合ログ）に追記
# - logs/<branch>_<author>.md（ブランチログ）に追記
input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // .tool_input.content // ""')

# git commit コマンドかチェック
if ! echo "$command" | grep -qE '^git commit'; then
  echo '{}'
  exit 0
fi

# コミットが成功したかチェック
error=$(echo "$input" | jq -r '.tool_response.error // ""')
if [ -n "$error" ] && [ "$error" != "null" ]; then
  echo "コミット失敗のためログ記録をスキップ" >&2
  echo '{}'
  exit 0
fi

# プロジェクトディレクトリ
project_dir="${GEMINI_PROJECT_DIR:-$(pwd)}"
logs_dir="$project_dir/logs"
mkdir -p "$logs_dir"

# コミット情報を取得
commit_hash=$(cd "$project_dir" && git log -1 --format="%h" 2>/dev/null)
commit_msg=$(cd "$project_dir" && git log -1 --format="%s" 2>/dev/null)
branch=$(cd "$project_dir" && git branch --show-current 2>/dev/null)
author=$(cd "$project_dir" && git config user.name 2>/dev/null || echo "unknown")
changed_files=$(cd "$project_dir" && git diff-tree --no-commit-id --name-only -r HEAD 2>/dev/null | head -10)
timestamp=$(date '+%Y-%m-%d %H:%M')
date_only=$(date '+%Y-%m-%d')

# ファイルリストをカンマ区切りに
files_list=$(echo "$changed_files" | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')

# --- 統合ログ（WORK_LOG.md）---
worklog="$logs_dir/WORK_LOG.md"
if [ ! -f "$worklog" ]; then
  cat > "$worklog" <<HEADER
# 作業ログ（統合）

全ブランチ・全作業者のコミットログを時系列で記録します。

---
HEADER
  echo "WORK_LOG.md を新規作成" >&2
fi

cat >> "$worklog" <<ENTRY

## $timestamp [$branch] @$author

- **意図**: $commit_msg
- **変更ファイル**: $files_list
- **コミット**: $commit_hash
ENTRY

# --- ブランチログ ---
safe_branch=$(echo "$branch" | tr '/' '-')
safe_author=$(echo "$author" | tr ' ' '-')
branch_log="$logs_dir/${safe_branch}_${safe_author}.md"

if [ ! -f "$branch_log" ]; then
  base_version=""
  if [ -f "$project_dir/package.json" ]; then
    base_version=$(cd "$project_dir" && jq -r '.version // ""' package.json 2>/dev/null)
  fi

  cat > "$branch_log" <<HEADER
# $branch / $author

- **開始日**: $date_only
- **ベース**: main ${base_version:+v$base_version}

---
HEADER
  echo "ブランチログを新規作成: $branch_log" >&2
fi

cat >> "$branch_log" <<ENTRY

## $timestamp

- **意図**: $commit_msg
- **変更ファイル**: $files_list
- **コミット**: $commit_hash
ENTRY

echo "ログ記録完了: WORK_LOG.md + ${safe_branch}_${safe_author}.md" >&2

cat <<RESPONSE
{
  "hookSpecificOutput": {
    "additionalContext": "作業ログを記録しました ($commit_hash: $commit_msg)\n統合ログ: logs/WORK_LOG.md\nブランチログ: logs/${safe_branch}_${safe_author}.md"
  }
}
RESPONSE
exit 0
