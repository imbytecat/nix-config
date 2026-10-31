import base64
import json
import os
import re
import tempfile
import urllib.request
from pathlib import Path


ASSET_NAME = "wanxiang-lts-zh-hans.gram"
API_URL = "https://api.github.com/repos/amzxyz/RIME-LMDG/releases/tags/LTS"


def update_hash(package, release):
    assets = [asset for asset in release["assets"] if asset["name"] == ASSET_NAME]
    if len(assets) != 1:
        raise ValueError(f"expected exactly one release asset: {ASSET_NAME}")
    asset = assets[0]
    digest = asset.get("digest")
    if (
        asset.get("state") != "uploaded"
        or asset.get("size", 0) <= 0
        or not isinstance(digest, str)
        or not re.fullmatch(r"sha256:[0-9a-f]{64}", digest)
    ):
        raise ValueError(f"release asset has no valid SHA256 digest: {ASSET_NAME}")

    # GitHub digest 与 fetchurl 默认的 flat hash 都校验原始文件字节。
    sri = "sha256-" + base64.b64encode(bytes.fromhex(digest[7:])).decode("ascii")
    source = package.read_text(encoding="utf-8")
    matches = list(
        re.finditer(r'(?m)^[ \t]*hash = "(sha256-[A-Za-z0-9+/]{43}=)";$', source)
    )
    if len(matches) != 1:
        raise ValueError(f"expected exactly one source hash in {package}")
    match = matches[0]
    old = match.group(1)
    if old == sri:
        print("rime-wanxiang-grammar: unchanged")
        return

    updated = source[:match.start(1)] + sri + source[match.end(1):]
    descriptor, temporary = tempfile.mkstemp(dir=package.parent, prefix=".rime-hash-")
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            stream.write(updated)
        os.chmod(temporary, package.stat().st_mode)
        os.replace(temporary, package)
    finally:
        Path(temporary).unlink(missing_ok=True)
    print(f"rime-wanxiang-grammar: {old} -> {sri}")


def main():
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "nix-config",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(API_URL, headers=headers)
    with urllib.request.urlopen(request, timeout=30) as response:
        release = json.load(response)
    update_hash(Path(__file__).with_name("default.nix"), release)


if __name__ == "__main__":
    main()
