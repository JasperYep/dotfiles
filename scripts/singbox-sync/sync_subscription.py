#!/usr/bin/env python3
import argparse
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path


def run(cmd, cwd=None):
    result = subprocess.run(cmd, cwd=cwd, text=True, capture_output=True)
    if result.returncode != 0:
        if result.stdout:
            sys.stderr.write(result.stdout)
        if result.stderr:
            sys.stderr.write(result.stderr)
        raise SystemExit(result.returncode)
    return result


def build_providers(source: str, user_agent: str, output_path: Path) -> dict:
    return {
        "subscribes": [
            {
                "url": source,
                "tag": "upstream",
                "enabled": True,
                "emoji": 0,
                "prefix": "",
                "User-Agent": user_agent,
            }
        ],
        "auto_set_outbounds_dns": {"proxy": "", "direct": ""},
        "save_config_path": str(output_path),
        "auto_backup": False,
        "exlude_protocol": "ssr",
        "config_template": "",
        "Only-nodes": True,
    }


def convert_nodes(converter_dir: Path, providers: dict) -> list[dict]:
    providers_path = converter_dir / "providers.json"
    original = providers_path.read_text(encoding="utf-8")
    try:
        providers_path.write_text(json.dumps(providers, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        run(
            [
                str(converter_dir / ".venv" / "bin" / "python"),
                "main.py",
                "--template_index",
                "0",
            ],
            cwd=converter_dir,
        )
    finally:
        providers_path.write_text(original, encoding="utf-8")

    nodes_path = Path(providers["save_config_path"])
    with open(nodes_path, "r", encoding="utf-8") as f:
        return json.load(f)


def is_metadata_node(node: dict) -> bool:
    tag = str(node.get("tag", ""))
    server = str(node.get("server", "")).strip().lower()
    server_port = node.get("server_port")
    if server in {"127.0.0.1", "::1", "localhost"}:
        return True
    if server == "" or server_port in {None, 0}:
        return True
    patterns = [
        r"剩余流量",
        r"套餐到期",
        r"官网",
        r"重置",
        r"过期",
        r"到期",
    ]
    return any(re.search(pattern, tag) for pattern in patterns)


def filter_nodes(nodes: list[dict]) -> list[dict]:
    filtered = [node for node in nodes if not is_metadata_node(node)]
    if not filtered:
        raise SystemExit("All generated nodes were filtered out as metadata")
    return filtered


def build_final_config(base: dict, nodes: list[dict]) -> dict:
    node_tags = [node["tag"] for node in nodes if node.get("tag")]
    if not node_tags:
        raise SystemExit("No usable nodes were produced from the subscription")

    auto = {
        "type": "urltest",
        "tag": "auto",
        "outbounds": node_tags,
        "url": "https://www.gstatic.com/generate_204",
        "interval": "10m",
        "tolerance": 50,
        "idle_timeout": "30m",
        "interrupt_exist_connections": False,
    }
    selector = {
        "type": "selector",
        "tag": "proxy",
        "outbounds": node_tags + ["auto"],
        "default": node_tags[0],
        "interrupt_exist_connections": False,
    }

    final_config = json.loads(json.dumps(base))
    final_config["outbounds"] = nodes + [auto, selector] + final_config.get("outbounds", [])

    for server in final_config.get("dns", {}).get("servers", []):
        if server.get("tag") == "proxy-dns":
            server["detour"] = "proxy"

    final_config.setdefault("route", {})["final"] = "proxy"
    return final_config


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--subscription-url")
    parser.add_argument("--source-file")
    parser.add_argument("--user-agent", default="clashmeta")
    parser.add_argument("--base-config", required=True)
    parser.add_argument("--converter-dir", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    if bool(args.subscription_url) == bool(args.source_file):
        raise SystemExit("Specify exactly one of --subscription-url or --source-file")

    source = args.source_file or args.subscription_url
    if args.source_file:
        source = str(Path(args.source_file).expanduser().resolve())

    base_path = Path(args.base_config).expanduser().resolve()
    converter_dir = Path(args.converter_dir).expanduser().resolve()
    output_path = Path(args.output).expanduser().resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with open(base_path, "r", encoding="utf-8") as f:
        base_config = json.load(f)

    with tempfile.TemporaryDirectory(prefix="singbox-sync-") as tmpdir:
        nodes_path = Path(tmpdir) / "nodes.json"
        providers = build_providers(source, args.user_agent, nodes_path)
        nodes = filter_nodes(convert_nodes(converter_dir, providers))

    final_config = build_final_config(base_config, nodes)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(final_config, f, indent=2, ensure_ascii=False)
        f.write("\n")

    tags = [node["tag"] for node in nodes if node.get("tag")]
    print(f"Generated {len(tags)} nodes")
    print(f"Default selector target: {tags[0]}")
    print(f"Config written to: {output_path}")


if __name__ == "__main__":
    main()
