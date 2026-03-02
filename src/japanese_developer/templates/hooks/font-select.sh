#!/usr/bin/env bash
# japanese-developer: ↑↓矢印キーでUDフォントを選択・自動インストール

# --- フォント定義 ---
# 形式: "表示名|説明|GitHubリポジトリ|zipパターン|ttfファイル名"
FONTS=(
  "UDEV Gothic|モリサワ BIZ UDゴシック + JetBrains Mono|yuru7/udev-gothic|UDEVGothic_v|UDEVGothic-Regular.ttf"
  "HackGen|Hack + 源柔ゴシック（プログラマー定番）|yuru7/HackGen|HackGen_v|HackGenConsole-Regular.ttf"
  "PlemolJP|IBM Plex Mono + IBM Plex Sans JP|yuru7/PlemolJP|PlemolJP_v|PlemolJPConsole-Regular.ttf"
  "キャンセル|フォントを変更しない||"
)

SELECTED=0
TOTAL=${#FONTS[@]}

# --- 描画 ---
draw_menu() {
  for i in "${!FONTS[@]}"; do
    IFS='|' read -r name desc _ _ _ <<< "${FONTS[$i]}"
    if [ "$i" -eq "$SELECTED" ]; then
      printf "  \033[7m > %s \033[0m %s\n" "$name" "$desc"
    else
      printf "    %s  %s\n" "$name" "$desc"
    fi
  done
}

# --- メニュー表示 ---
echo ""
echo "  フォントを選んでください（↑↓で選択、エンターで決定）"
echo ""
draw_menu

# --- キー入力ループ ---
while true; do
  IFS= read -rsn1 key
  if [[ "$key" == $'\e' ]]; then
    read -rsn2 rest
    key+="$rest"
  fi

  case "$key" in
    $'\e[A') # ↑
      ((SELECTED > 0)) && ((SELECTED--))
      ;;
    $'\e[B') # ↓
      ((SELECTED < TOTAL - 1)) && ((SELECTED++))
      ;;
    '') # エンター
      break
      ;;
  esac

  # カーソルを戻して再描画
  printf "\033[%dA" "$TOTAL"
  draw_menu
done

# --- 選択結果を取得 ---
IFS='|' read -r NAME DESC REPO ZIP_PREFIX TTF_NAME <<< "${FONTS[$SELECTED]}"

if [ "$NAME" = "キャンセル" ] || [ -z "$REPO" ]; then
  echo ""
  echo "  キャンセルしました。"
  exit 0
fi

echo ""
echo "  ${NAME} をダウンロードしています..."

# --- 最新リリースのzipダウンロードURLを取得 ---
if command -v gh &>/dev/null; then
  DOWNLOAD_URL=$(gh api "repos/${REPO}/releases/latest" \
    --jq ".assets[] | select(.name | startswith(\"${ZIP_PREFIX}\")) | .browser_download_url" \
    2>/dev/null | head -1)
else
  DOWNLOAD_URL=$(curl -sL "https://api.github.com/repos/${REPO}/releases/latest" \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
for a in data.get('assets', []):
    if a['name'].startswith('${ZIP_PREFIX}'):
        print(a['browser_download_url'])
        break
" 2>/dev/null)
fi

if [ -z "$DOWNLOAD_URL" ]; then
  echo "  ダウンロードURLの取得に失敗しました。"
  echo "  ネットワーク接続を確認してください。"
  exit 1
fi

# --- ダウンロード＆展開 ---
TMPDIR=$(mktemp -d)
ZIP_PATH="${TMPDIR}/font.zip"

if ! curl -sL "$DOWNLOAD_URL" -o "$ZIP_PATH"; then
  echo "  ダウンロードに失敗しました。"
  rm -rf "$TMPDIR"
  exit 1
fi

if ! unzip -q "$ZIP_PATH" -d "$TMPDIR"; then
  echo "  zipの展開に失敗しました。"
  rm -rf "$TMPDIR"
  exit 1
fi

# --- フォントファイルを探す ---
FONT_FILE=$(find "$TMPDIR" -name "$TTF_NAME" -type f | head -1)

if [ -z "$FONT_FILE" ]; then
  echo "  フォントファイル ${TTF_NAME} が見つかりませんでした。"
  rm -rf "$TMPDIR"
  exit 1
fi

# --- インストール ---
mkdir -p ~/.termux
cp "$FONT_FILE" ~/.termux/font.ttf
rm -rf "$TMPDIR"

# --- 適用 ---
termux-reload-settings 2>/dev/null

echo ""
echo "  ✅ ${NAME} を適用しました。"
echo "  （元に戻すには ~/.termux/font.ttf を削除して termux-reload-settings）"
echo ""
