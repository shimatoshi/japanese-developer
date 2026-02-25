#!/usr/bin/env bash
# AfterTool hook: git push 検出後にPRへ作業ログを同期
# - PR未作成時: スキップ
# - PR作成済み時: 最新のログエントリをPRコメントとして投稿
input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // .tool_input.content // ""')

# git push コマンドかチェック
if ! echo "$command" | grep -qE '^git push'; then
  echo '{}'
  exit 0
fi

# pushが成功したかチェック
error=$(echo "$input" | jq -r '.tool_response.error // ""')
if [ -n "$error" ] && [ "$error" != "null" ]; then
  echo "push失敗のためPRログ同期をスキップ" >&2
  echo '{}'
  exit 0
fi

project_dir="${GEMINI_PROJECT_DIR:-$(pwd)}"
branch=$(cd "$project_dir" && git branch --show-current 2>/dev/null)

# mainブランチへのpushはスキップ
if [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
  echo '{}'
  exit 0
fi

# gh コマンドが使えるか確認
if ! command -v gh &>/dev/null; then
  echo "gh コマンドが見つかりません" >&2
  echo '{}'
  exit 0
fi

# PRが存在するか確認
pr_number=$(cd "$project_dir" && gh pr view "$branch" --json number -q '.number' 2>/dev/null)
if [ -z "$pr_number" ] || [ "$pr_number" = "null" ]; then
  echo "PRが見つかりません、スキップ" >&2
  echo '{}'
  exit 0
fi

# ブランチログを取得
author=$(cd "$project_dir" && git config user.name 2>/dev/null || echo "unknown")
safe_branch=$(echo "$branch" | tr '/' '-')
safe_author=$(echo "$author" | tr ' ' '-')
branch_log="$project_dir/logs/${safe_branch}_${safe_author}.md"

if [ ! -f "$branch_log" ]; then
  echo "ブランチログが見つかりません: $branch_log" >&2
  echo '{}'
  exit 0
fi

# 直近のコミット情報（pushに含まれるもの）
latest_commits=$(cd "$project_dir" && git log origin/$branch..HEAD --format="- %h: %s" 2>/dev/null)
if [ -z "$latest_commits" ]; then
  # pushが成功して差分がない場合は直近1件
  latest_commits=$(cd "$project_dir" && git log -1 --format="- %h: %s" 2>/dev/null)
fi

timestamp=$(date '+%Y-%m-%d %H:%M')

# PRコメントを投稿
comment_body="## 📋 作業ログ更新 ($timestamp)

**ブランチ**: \`$branch\`
**作業者**: @$author

### 今回のコミット
$latest_commits

---
<details>
<summary>ブランチログ全文</summary>

$(cat "$branch_log")

</details>"

cd "$project_dir" && gh pr comment "$pr_number" --body "$comment_body" 2>/dev/null

if [ $? -eq 0 ]; then
  echo "PR #$pr_number にログコメントを投稿" >&2
else
  echo "PRコメント投稿に失敗" >&2
fi

cat <<RESPONSE
{
  "hookSpecificOutput": {
    "additionalContext": "PR #$pr_number に作業ログを投稿しました"
  }
}
RESPONSE
exit 0
