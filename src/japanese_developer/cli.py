"""japanese-developer CLI: Gemini CLI汎用環境セットアップ"""

import json
import os
import shutil
import stat
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
    expected = ["enforce-japanese.sh", "block-server-start.sh", "auto-worklog.sh"]
    for name in expected:
        _check_file(hooks_dir / name, f"hooks/{name}")

    click.echo()


@main.command()
def uninstall():
    """japanese-developer が導入したhookを削除する"""

    hooks_dir = GEMINI_DIR / "hooks"
    managed_hooks = ["enforce-japanese.sh", "block-server-start.sh", "auto-worklog.sh"]
    managed_names = ["enforce-japanese", "block-server-start", "auto-worklog"]

    removed = []

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


if __name__ == "__main__":
    main()
