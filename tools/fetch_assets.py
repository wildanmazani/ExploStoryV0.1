"""Download PixelLab assets listed in tools/asset_manifest.json into assets/.

Run: python tools/fetch_assets.py   (skips files that already exist)
"""
import json
import os
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
API = "https://api.pixellab.ai/mcp"
CHAR_CDN = "https://backblaze.pixellab.ai/file/pixellab-characters/0e17d7c0-0552-4245-9c0c-71eab12e5dcf"
DIRS = ["south", "east", "north", "west"]


def jobs():
    m = json.load(open(os.path.join(ROOT, "tools", "asset_manifest.json")))
    for name, cid in m["characters"].items():
        for d in DIRS:
            yield f"{CHAR_CDN}/{cid}/rotations/{d}.png", f"assets/characters32/{name}/{name}_{d}.png"
    for name, anim in m.get("animations", {}).items():
        for d, (anim_id, frames) in anim["dirs"].items():
            for i in range(frames):
                url = f"{CHAR_CDN}/{anim['character']}/animations/{anim_id}/{d}/{i}.png"
                yield url, f"assets/characters32/{name}/{name}_{d}_{i}.png"
    for name, tid in m["tilesets"].items():
        yield f"{API}/tilesets/{tid}/image?inline=true", f"assets/tiles/{name}_image.png"
        yield f"{API}/tilesets/{tid}/metadata", f"assets/tiles/{name}_metadata.json"
    for name, oid in m["objects"].items():
        yield f"{API}/map-objects/{oid}/download", f"assets/objects/{name}.png"


def fetch(job):
    url, rel = job
    dest = os.path.join(ROOT, rel)
    if os.path.exists(dest) and os.path.getsize(dest) > 0:
        return f"skip {rel}"
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "explostory-fetch"})
        with urllib.request.urlopen(req, timeout=60) as r:
            data = r.read()
        with open(dest, "wb") as f:
            f.write(data)
        return f"ok   {rel}"
    except Exception as e:  # report and continue
        return f"FAIL {rel}: {e}"


if __name__ == "__main__":
    with ThreadPoolExecutor(8) as pool:
        results = list(pool.map(fetch, list(jobs())))
    fails = [r for r in results if r.startswith("FAIL")]
    print(f"{len(results)} files, {len(fails)} failed")
    print("\n".join(fails))
    sys.exit(1 if fails else 0)
