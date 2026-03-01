#!/bin/bash
# interactive-guard.sh
# 対話型コマンドを検知し、非対話フラグ付きの代替を提案するフック

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# コマンドが空なら許可
if [ -z "$COMMAND" ]; then
  echo '{"decision": "allow"}'
  exit 0
fi

# --- npm create / npm create vite (--no-interactive なし) ---
# 重要: --no-interactive は -- の後に置く（create-viteに渡すため）
if [[ "$COMMAND" =~ npm[[:space:]]+create ]] && [[ ! "$COMMAND" =~ --no-interactive ]]; then
  REASON="対話型コマンド検知: 'npm create' は対話プロンプトが発生します。-- の後に --no-interactive を付けてください。例: npm create vite@latest my-app -- --template react-ts --no-interactive"
  echo "{\"decision\": \"deny\", \"reason\": \"$REASON\"}"
  exit 0
fi

# --- npm init (-y なし) ---
if [[ "$COMMAND" =~ npm[[:space:]]+init ]] && [[ ! "$COMMAND" =~ -y ]] && [[ ! "$COMMAND" =~ --yes ]]; then
  REASON="対話型コマンド検知: 'npm init' は対話プロンプトが発生します。'-y' フラグを付けてください。例: npm init -y"
  echo "{\"decision\": \"deny\", \"reason\": \"$REASON\"}"
  exit 0
fi

# --- npx create-react-app (--template なし) ---
if [[ "$COMMAND" =~ npx[[:space:]]+create-react-app ]] && [[ ! "$COMMAND" =~ --template ]]; then
  REASON="対話型コマンド検知: 'npx create-react-app' には --template を指定してください。例: npx create-react-app my-app --template typescript"
  echo "{\"decision\": \"deny\", \"reason\": \"$REASON\"}"
  exit 0
fi

# --- yarn create (--template なし) ---
if [[ "$COMMAND" =~ yarn[[:space:]]+create ]] && [[ ! "$COMMAND" =~ --template ]]; then
  REASON="対話型コマンド検知: 'yarn create' は対話プロンプトが発生します。--template フラグを付けてください。例: yarn create vite my-app --template react-ts"
  echo "{\"decision\": \"deny\", \"reason\": \"$REASON\"}"
  exit 0
fi

# --- git rebase -i (対話的リベース) ---
if [[ "$COMMAND" =~ git[[:space:]]+rebase[[:space:]]+-i ]] || [[ "$COMMAND" =~ git[[:space:]]+rebase[[:space:]]+--interactive ]]; then
  REASON="対話型コマンド検知: 'git rebase -i' はエディタが開くため実行できません。非対話的な git rebase を使用してください。"
  echo "{\"decision\": \"deny\", \"reason\": \"$REASON\"}"
  exit 0
fi

# --- mysql 対話シェル (-e なし) ---
if [[ "$COMMAND" =~ mysql[[:space:]] ]] && [[ ! "$COMMAND" =~ -e[[:space:]] ]] && [[ ! "$COMMAND" =~ --execute ]]; then
  REASON="対話型コマンド検知: 'mysql' は対話シェルが開きます。-e フラグでSQLを直接渡してください。例: mysql -u root -e 'SHOW DATABASES;'"
  echo "{\"decision\": \"deny\", \"reason\": \"$REASON\"}"
  exit 0
fi

# --- psql 対話シェル (-c なし) ---
if [[ "$COMMAND" =~ psql[[:space:]] ]] && [[ ! "$COMMAND" =~ -c[[:space:]] ]] && [[ ! "$COMMAND" =~ --command ]] && [[ ! "$COMMAND" =~ -f[[:space:]] ]] && [[ ! "$COMMAND" =~ --file ]]; then
  REASON="対話型コマンド検知: 'psql' は対話シェルが開きます。-c フラグでSQLを直接渡してください。例: psql -c 'SELECT 1;'"
  echo "{\"decision\": \"deny\", \"reason\": \"$REASON\"}"
  exit 0
fi

# --- python/python3 (スクリプト指定なし = 対話シェル) ---
if [[ "$COMMAND" =~ ^python3?[[:space:]]*$ ]]; then
  REASON="対話型コマンド検知: 'python' は対話シェルが開きます。-c フラグでコードを直接渡すか、スクリプトファイルを指定してください。例: python3 -c 'print(1)'"
  echo "{\"decision\": \"deny\", \"reason\": \"$REASON\"}"
  exit 0
fi

# --- node (スクリプト指定なし = REPL) ---
if [[ "$COMMAND" =~ ^node[[:space:]]*$ ]]; then
  REASON="対話型コマンド検知: 'node' は対話REPLが開きます。-e フラグでコードを直接渡すか、スクリプトファイルを指定してください。例: node -e 'console.log(1)'"
  echo "{\"decision\": \"deny\", \"reason\": \"$REASON\"}"
  exit 0
fi

# --- ssh (対話シェル、コマンド指定なし) ---
if [[ "$COMMAND" =~ ^ssh[[:space:]] ]] && [[ ! "$COMMAND" =~ [[:space:]][\'\"] ]]; then
  # ssh user@host 'command' のようにコマンドが渡されていない場合
  WORDS=$(echo "$COMMAND" | wc -w)
  if [ "$WORDS" -le 3 ]; then
    REASON="対話型コマンド検知: 'ssh' は対話シェルが開きます。リモートで実行するコマンドを引数に渡してください。例: ssh user@host 'ls -la'"
    echo "{\"decision\": \"deny\", \"reason\": \"$REASON\"}"
    exit 0
  fi
fi

# --- 長時間実行サーバー系コマンド ---
# サーバー起動はCLI内では不可能。ユーザーに別ターミナルでの起動を依頼させる。
IS_SERVER=false

# npm/yarn/pnpm run dev|start|serve|preview
if [[ "$COMMAND" =~ (npm|npx|yarn|pnpm)[[:space:]]+(run[[:space:]]+)?(dev|start|serve|preview) ]]; then
  IS_SERVER=true
fi

# npx vite, npx next, npx serve 等の直接起動
if [[ "$COMMAND" =~ npx[[:space:]]+(vite|next|serve|nuxt|astro) ]]; then
  IS_SERVER=true
fi

# uvicorn
if [[ "$COMMAND" =~ uvicorn[[:space:]] ]]; then
  IS_SERVER=true
fi

# flask run, django runserver, rails server
if [[ "$COMMAND" =~ (flask[[:space:]]+run|python.*manage\.py[[:space:]]+runserver|rails[[:space:]]+s(erver)?) ]]; then
  IS_SERVER=true
fi

# python -m http.server
if [[ "$COMMAND" =~ python.*http\.server ]]; then
  IS_SERVER=true
fi

if [ "$IS_SERVER" = true ]; then
  EXAMPLE=$(echo "$COMMAND" | sed 's/[[:space:]]*$//')
  FINAL_REASON="BLOCKED: サーバー起動はこのターミナル内では実行できません。ユーザーに「別のターミナルで ${EXAMPLE} を実行してください」と伝えてください。サーバーが起動済みかどうかは curl で確認できます。"
  echo "{\"decision\": \"deny\", \"reason\": \"$FINAL_REASON\"}"
  exit 0
fi

# --- パターンに一致しない場合は許可 ---
echo '{"decision": "allow"}'
exit 0
