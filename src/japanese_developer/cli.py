"""japanese-developer CLI: Gemini CLI汎用環境セットアップ"""

import json
import os
import shutil
import stat
import subprocess
import sys
from datetime import datetime
from pathlib import Path

import click

GEMINI_DIR = Path.home() / ".gemini"
TEMPLATES_DIR = Path(__file__).parent / "templates"


def merge_hooks(existing: dict, new_hooks: dict) -> dict:
    """既存のsettings.jsonにhook設定をマージする。既存hookは保持。"""
    if "hooks" not in existing:
        existing["hooks"] = {}

    for event, hook_groups in new_hooks.items():
        if event not in existing["hooks"]:
            existing["hooks"][event] = hook_groups
        else:
            # 既存のhook名を収集
            existing_names = set()
            for group in existing["hooks"][event]:
                for h in group.get("hooks", []):
                    existing_names.add(h.get("name", ""))

            # 重複しないhookだけ追加
            for group in hook_groups:
                new_group_hooks = [
                    h for h in group.get("hooks", [])
                    if h.get("name", "") not in existing_names
                ]
                if new_group_hooks:
                    group["hooks"] = new_group_hooks
                    existing["hooks"][event].append(group)

    return existing


@click.group()
@click.version_option()
def main():
    """Gemini CLI用の汎用コーディング環境セットアップツール"""
    pass


@main.command()
@click.option("--force", is_flag=True, help="既存ファイルを上書きする")
def setup(force):
    """~/.gemini/ にhook・システムプロンプトを導入する"""

    # ディレクトリ作成
    hooks_dir = GEMINI_DIR / "hooks"
    hooks_dir.mkdir(parents=True, exist_ok=True)

    installed = []
    skipped = []

    # --- GEMINI.md ---
    gemini_md = GEMINI_DIR / "GEMINI.md"
    src_gemini_md = TEMPLATES_DIR / "GEMINI.md"
    if not gemini_md.exists() or force:
        shutil.copy2(src_gemini_md, gemini_md)
        installed.append("GEMINI.md")
    else:
        skipped.append("GEMINI.md（既に存在。--force で上書き）")

    # --- primer.md ---
    primer_md = GEMINI_DIR / "primer.md"
    src_primer_md = TEMPLATES_DIR / "primer.md"
    if not primer_md.exists() or force:
        shutil.copy2(src_primer_md, primer_md)
        installed.append("primer.md")
    else:
        skipped.append("primer.md（既に存在。--force で上書き）")

    # --- hookスクリプト ---
    hooks_src = TEMPLATES_DIR / "hooks"
    for script in hooks_src.iterdir():
        dest = hooks_dir / script.name
        if not dest.exists() or force:
            shutil.copy2(script, dest)
            # 実行権限付与
            dest.chmod(dest.stat().st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)
            installed.append(f"hooks/{script.name}")
        else:
            skipped.append(f"hooks/{script.name}（既に存在）")

    # --- カスタムコマンド ---
    commands_dir = GEMINI_DIR / "commands"
    commands_dir.mkdir(parents=True, exist_ok=True)
    commands_src = TEMPLATES_DIR / "commands"
    if commands_src.exists():
        for cmd_file in commands_src.iterdir():
            dest = commands_dir / cmd_file.name
            if not dest.exists() or force:
                shutil.copy2(cmd_file, dest)
                installed.append(f"commands/{cmd_file.name}")
            else:
                skipped.append(f"commands/{cmd_file.name}（既に存在）")

    # --- settings.json へhook設定をマージ ---
    settings_path = GEMINI_DIR / "settings.json"
    hooks_json_path = TEMPLATES_DIR / "hooks.json"

    if settings_path.exists():
        with open(settings_path, "r") as f:
            settings = json.load(f)
    else:
        settings = {}

    with open(hooks_json_path, "r") as f:
        new_hooks = json.load(f)

    settings = merge_hooks(settings, new_hooks)

    with open(settings_path, "w") as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)
    installed.append("settings.json（hook設定をマージ）")

    # --- 結果表示 ---
    click.echo()
    click.secho("✅ japanese-developer セットアップ完了", fg="green", bold=True)
    click.echo()

    if installed:
        click.secho("導入済み:", fg="cyan")
        for item in installed:
            click.echo(f"  ✓ {item}")

    if skipped:
        click.echo()
        click.secho("スキップ:", fg="yellow")
        for item in skipped:
            click.echo(f"  - {item}")

    click.echo()
    click.echo(f"設定先: {GEMINI_DIR}")
    click.echo()
    click.secho("次にやること:", fg="cyan")
    click.echo("  1. ~/.gemini/GEMINI.md を確認・カスタマイズ")
    click.echo("  2. Gemini CLI を起動して動作確認")
    click.echo("  3. 環境変数は ~/.gemini/ENV.md に手動で記載")


@main.command()
def status():
    """現在のインストール状態を確認する"""

    click.secho("japanese-developer 状態確認", fg="cyan", bold=True)
    click.echo()

    # GEMINI.md
    gemini_md = GEMINI_DIR / "GEMINI.md"
    _check_file(gemini_md, "GEMINI.md")

    # primer.md
    primer_md = GEMINI_DIR / "primer.md"
    _check_file(primer_md, "primer.md")

    # settings.json のhook設定
    settings_path = GEMINI_DIR / "settings.json"
    if settings_path.exists():
        with open(settings_path) as f:
            settings = json.load(f)
        hooks = settings.get("hooks", {})
        hook_count = sum(
            len(h.get("hooks", []))
            for groups in hooks.values()
            for h in groups
        )
        click.echo(f"  ✓ settings.json（hook {hook_count}件登録済み）")
    else:
        click.echo("  ✗ settings.json が見つかりません")

    # hookスクリプト
    hooks_dir = GEMINI_DIR / "hooks"
    expected = ["enforce-japanese.sh", "interactive-guard.sh", "auto-worklog.sh", "pr-log-sync.sh", "syntax-check.sh", "primer.sh", "font-select.sh"]
    for name in expected:
        _check_file(hooks_dir / name, f"hooks/{name}")

    click.echo()


@main.command()
def uninstall():
    """japanese-developer が導入したhookを削除する"""

    hooks_dir = GEMINI_DIR / "hooks"
    managed_hooks = ["enforce-japanese.sh", "interactive-guard.sh", "auto-worklog.sh", "pr-log-sync.sh", "syntax-check.sh", "primer.sh", "font-select.sh"]
    managed_names = ["enforce-japanese", "interactive-guard", "auto-worklog", "pr-log-sync", "syntax-check", "primer"]
    managed_commands = ["plan.md", "review.md"]

    removed = []

    # primer.md 削除
    primer_md = GEMINI_DIR / "primer.md"
    if primer_md.exists():
        primer_md.unlink()
        removed.append("primer.md")

    # カスタムコマンド削除
    commands_dir = GEMINI_DIR / "commands"
    for name in managed_commands:
        path = commands_dir / name
        if path.exists():
            path.unlink()
            removed.append(f"commands/{name}")

    # hookスクリプト削除
    for name in managed_hooks:
        path = hooks_dir / name
        if path.exists():
            path.unlink()
            removed.append(f"hooks/{name}")

    # settings.json からhook設定を除去
    settings_path = GEMINI_DIR / "settings.json"
    if settings_path.exists():
        with open(settings_path) as f:
            settings = json.load(f)

        if "hooks" in settings:
            for event in list(settings["hooks"].keys()):
                new_groups = []
                for group in settings["hooks"][event]:
                    group["hooks"] = [
                        h for h in group.get("hooks", [])
                        if h.get("name", "") not in managed_names
                    ]
                    if group["hooks"]:
                        new_groups.append(group)
                if new_groups:
                    settings["hooks"][event] = new_groups
                else:
                    del settings["hooks"][event]

            if not settings["hooks"]:
                del settings["hooks"]

        with open(settings_path, "w") as f:
            json.dump(settings, f, indent=2, ensure_ascii=False)
        removed.append("settings.json（hook設定を除去）")

    click.echo()
    if removed:
        click.secho("🗑️  削除完了:", fg="yellow")
        for item in removed:
            click.echo(f"  - {item}")
        click.echo()
        click.echo("※ GEMINI.md は手動で管理してください")
    else:
        click.echo("削除するものがありませんでした")


def _check_file(path: Path, label: str):
    if path.exists():
        size = path.stat().st_size
        click.echo(f"  ✓ {label}（{size} bytes）")
    else:
        click.echo(f"  ✗ {label} が見つかりません")


def _run_cmd(cmd: str) -> str:
    """コマンドを実行して出力を返す。失敗時は空文字。"""
    try:
        result = subprocess.run(
            cmd, shell=True, capture_output=True, text=True, timeout=10
        )
        return result.stdout.strip()
    except Exception:
        return ""


def _collect_env_info() -> dict:
    """環境情報を自動収集する。"""
    info = {}
    info["日時"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    info["OS"] = _run_cmd("uname -a") or "取得失敗"
    info["Python"] = _run_cmd("python3 --version") or _run_cmd("python --version") or "未インストール"
    info["Node.js"] = _run_cmd("node --version") or "未インストール"
    info["npm"] = _run_cmd("npm --version") or "未インストール"
    info["git"] = _run_cmd("git --version") or "未インストール"
    info["カレントディレクトリ"] = os.getcwd()

    # git情報（リポジトリ内の場合のみ）
    git_status = _run_cmd("git status --short 2>/dev/null")
    if git_status:
        info["git status"] = git_status
    git_log = _run_cmd("git log --oneline -3 2>/dev/null")
    if git_log:
        info["直近コミット"] = git_log
    git_branch = _run_cmd("git branch --show-current 2>/dev/null")
    if git_branch:
        info["ブランチ"] = git_branch

    # package.json があれば依存パッケージ
    pkg_path = Path.cwd() / "package.json"
    if pkg_path.exists():
        try:
            with open(pkg_path) as f:
                pkg = json.load(f)
            deps = pkg.get("dependencies", {})
            dev_deps = pkg.get("devDependencies", {})
            if deps or dev_deps:
                dep_lines = [f"  {k}: {v}" for k, v in {**deps, **dev_deps}.items()]
                info["package.json 依存関係"] = "\n".join(dep_lines)
        except Exception:
            pass

    # requirements.txt があれば
    req_path = Path.cwd() / "requirements.txt"
    if req_path.exists():
        try:
            content = req_path.read_text().strip()
            if content:
                info["requirements.txt"] = content
        except Exception:
            pass

    return info


def _read_multiline(prompt_msg: str) -> str:
    """複数行入力を受け付ける。空行で終了。"""
    click.echo(prompt_msg)
    click.secho("  （入力後、空行でEnterを押すと確定）", fg="bright_black")
    lines = []
    while True:
        try:
            line = input()
        except EOFError:
            break
        if line == "":
            if lines:
                break
            continue
        lines.append(line)
    return "\n".join(lines)


@main.command()
@click.option("--output", "-o", type=click.Path(), help="レポートをファイルに保存")
@click.option("--auto", "auto_only", is_flag=True, help="対話をスキップして環境情報のみ収集")
def error(output, auto_only):
    """エラー情報を収集してコーディングエージェント用レポートを生成する"""

    click.echo()
    click.secho("🔍 エラー診断レポート作成", fg="cyan", bold=True)
    click.echo()

    # --- 対話パート ---
    user_answers = {}
    if not auto_only:
        click.secho("エラーについて教えてください（エージェントに渡すための情報収集です）", fg="yellow")
        click.echo()

        # 1. 何をしようとしていたか
        user_answers["やろうとしていたこと"] = click.prompt(
            "❶ 何をしようとしていた？（例: npm run devでサーバーを起動しようとした）"
        )
        click.echo()

        # 2. エラーメッセージ
        user_answers["エラーメッセージ"] = _read_multiline(
            "❷ エラーメッセージを貼り付けてください:"
        )
        click.echo()

        # 3. 実行したコマンド
        user_answers["実行したコマンド"] = click.prompt(
            "❸ 実行したコマンドは？（例: npm run dev）",
            default="", show_default=False
        )
        click.echo()

        # 4. いつから
        click.echo("❹ いつから発生している？")
        choices = {"1": "最初から（一度も動いたことがない）", "2": "さっきまで動いてた", "3": "わからない"}
        for k, v in choices.items():
            click.echo(f"  {k}. {v}")
        since = click.prompt("番号を選択", type=click.Choice(["1", "2", "3"]), default="3")
        user_answers["発生時期"] = choices[since]
        click.echo()

        # 5. 最近変更したこと
        user_answers["最近の変更"] = click.prompt(
            "❺ 最近変更したことは？（例: パッケージを追加した、設定ファイルをいじった）",
            default="特になし / わからない", show_default=True
        )
        click.echo()
    else:
        click.echo("--auto: 環境情報のみ収集します")
        click.echo()

    # --- 環境情報収集 ---
    click.secho("環境情報を収集中...", fg="bright_black")
    env_info = _collect_env_info()

    # --- レポート生成 ---
    report_lines = []
    report_lines.append("# エラー診断レポート")
    report_lines.append("")
    report_lines.append(f"生成日時: {env_info.pop('日時')}")
    report_lines.append("")

    if user_answers:
        report_lines.append("## エラー内容")
        report_lines.append("")
        for key, val in user_answers.items():
            if "\n" in val:
                report_lines.append(f"### {key}")
                report_lines.append("```")
                report_lines.append(val)
                report_lines.append("```")
            else:
                report_lines.append(f"- **{key}**: {val}")
        report_lines.append("")

    report_lines.append("## 環境情報")
    report_lines.append("")
    for key, val in env_info.items():
        if "\n" in val:
            report_lines.append(f"### {key}")
            report_lines.append("```")
            report_lines.append(val)
            report_lines.append("```")
        else:
            report_lines.append(f"- **{key}**: {val}")
    report_lines.append("")

    report = "\n".join(report_lines)

    # --- 出力 ---
    click.echo()
    click.secho("━" * 50, fg="cyan")
    click.echo(report)
    click.secho("━" * 50, fg="cyan")

    if output:
        out_path = Path(output)
        out_path.write_text(report, encoding="utf-8")
        click.echo()
        click.secho(f"📄 レポートを保存しました: {out_path}", fg="green")

    click.echo()
    click.secho("使い方:", fg="yellow")
    click.echo("  上のレポートをコピーしてコーディングエージェントに貼り付けてください。")
    click.echo("  エージェントがエラーの原因を診断してくれます。")


TERMUX_UI_SETTINGS = {
    "useAlternateBuffer": False,
    "hideBanner": True,
    "hideFooter": True,
    "hideContextSummary": True,
    "hideTips": True,
    "incrementalRendering": True,
}

PRIMER_DISPLAY_SCRIPT = """
# japanese-developer: gemini起動時プライマー表示
jd-primer() {
  if [ -f "$HOME/.gemini/hooks/primer.sh" ]; then
    echo '{}' | bash "$HOME/.gemini/hooks/primer.sh" 2>&1 >/dev/null
    while true; do
      read -r -p "  (番号で詳細表示 / エンターで続行) " choice
      case "$choice" in
        "") break ;;
        1) echo ""; echo "  Termuxとは？"; echo "  スマホの中にある「キッチン」のようなものです。"; echo "  Node.jsやPythonは鍋や包丁のような調理道具で、"; echo "  gitは冷蔵庫（材料の保管と出し入れ）にあたります。"; echo "  どんな道具を使って何を作るかはすべてあなた次第です。"; echo "" ;;
        2) echo ""; echo "  gitとは？"; echo "  作ったモノの「セーブデータ管理」です。"; echo "  git add（材料を並べる）→ git commit（調理完了の記録）"; echo "  → git push（冷蔵庫に保存）が基本の流れです。"; echo "" ;;
        3) echo ""; echo "  Gemini CLIとは？"; echo "  Googleが作ったAIの助手です。"; echo "  「これ作って」と言えばコードを書きますし、"; echo "  「これ何？」と聞けば説明してくれます。"; echo "" ;;
        4) echo ""; echo "  コーディングエージェントとは？"; echo "  AIがコードの読み書き・実行・デバッグまで自律的にやってくれる仕組み。"; echo "  あなたがシェフで、エージェントは腕のいい助手です。"; echo "" ;;
        5) echo ""; echo "  無責任者連絡先（無保証・無責任）:"; echo "  shimadatoshiyuki839@gmail.com"; echo "" ;;
        6) echo ""; echo "  git連携:"; if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then echo "  ユーザー: $(git config user.name)"; echo "  ブランチ: $(git branch --show-current)"; echo "  リモート: $(git remote get-url origin 2>/dev/null || echo なし)"; echo "  未コミット: $(git status --short | wc -l | tr -d ' ')件"; else echo "  （gitリポジトリ外）"; fi; echo "" ;;
        7) echo ""; echo "  コマンド一覧:"; echo "  japanese-developer setup/status/error/termux-setup/uninstall"; if [ -d "$HOME/.gemini/commands" ]; then for f in "$HOME/.gemini/commands"/*.md; do [ -f "$f" ] && echo "  /$(basename "$f" .md)"; done; fi; echo "" ;;
        8) if [ -f "$HOME/.gemini/hooks/font-select.sh" ]; then bash "$HOME/.gemini/hooks/font-select.sh"; else echo ""; echo "  font-select.sh が見つかりません。japanese-developer setup --force を実行してください。"; echo ""; fi ;;
        *) echo "  1〜8の番号を入力してください。" ;;
      esac
    done
  fi
}
"""

TERMUX_ALIASES = """
# Gemini CLI - Termux aliases (japanese-developer)
alias gemini='jd-primer && trap "" SIGWINCH && command gemini'
alias gemini-safe='jd-primer && trap "" SIGWINCH && NO_COLOR=1 command gemini'
alias gemini-plain='jd-primer && trap "" SIGWINCH && command gemini --screenReader'
"""


@main.command(name="termux-setup")
def termux_setup():
    """Termux環境向けのGemini CLI UI最適化を適用する"""

    settings_path = GEMINI_DIR / "settings.json"

    if settings_path.exists():
        with open(settings_path, "r") as f:
            settings = json.load(f)
    else:
        settings = {}

    # UI設定をマージ
    if "ui" not in settings:
        settings["ui"] = {}
    settings["ui"].update(TERMUX_UI_SETTINGS)

    with open(settings_path, "w") as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)

    click.echo()
    click.secho("✅ Termux UI最適化を適用しました", fg="green", bold=True)
    click.echo()
    click.secho("適用した設定:", fg="cyan")
    for key, val in TERMUX_UI_SETTINGS.items():
        click.echo(f"  ✓ {key}: {val}")

    # bashrc エイリアス・プライマー関数
    bashrc = Path.home() / ".bashrc"
    bashrc_content = bashrc.read_text() if bashrc.exists() else ""

    primer_marker = "# japanese-developer: gemini起動時プライマー表示"
    alias_marker = "# Gemini CLI - Termux aliases (japanese-developer)"

    added_items = []

    if primer_marker not in bashrc_content:
        with open(bashrc, "a") as f:
            f.write(PRIMER_DISPLAY_SCRIPT)
        added_items.append("jd-primer 関数（起動時メニュー表示）")

    bashrc_content = bashrc.read_text() if bashrc.exists() else ""
    if alias_marker not in bashrc_content:
        with open(bashrc, "a") as f:
            f.write(TERMUX_ALIASES)
        added_items.append("gemini エイリアス（プライマー付き起動）")
        added_items.append("gemini-safe（色なしモード）")
        added_items.append("gemini-plain（screenReaderモード）")

    if added_items:
        click.echo()
        click.secho("bashrcに追加:", fg="cyan")
        for item in added_items:
            click.echo(f"  ✓ {item}")
    else:
        click.echo()
        click.echo("  - bashrcエイリアス（既に存在）")

    click.echo()
    click.secho("次にやること:", fg="cyan")
    click.echo("  1. source ~/.bashrc でエイリアスを反映")
    click.echo("  2. gemini を起動してUI改善を確認")


if __name__ == "__main__":
    main()
