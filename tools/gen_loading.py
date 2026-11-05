"""Web loading screen: Alif runs along the loading bar after a bouncing Pau.

Godot's web page shows a plain bar while the game downloads. This writes a
small block (CSS + JS + the sprites as data URIs) into html/head_include in
export_presets.cfg, between <!--muat--> and <!--/muat-->, so rerunning it
replaces the old block and keeps everything else (the fullscreen button).

    python tools/gen_loading.py
"""
import base64
import io
import pathlib
import re

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
PRESETS = ROOT / "export_presets.cfg"
FRAMES = [ROOT / f"assets/characters32/alif_walk/alif_walk_east_{i}.png" for i in range(6)]
PAU = ROOT / "assets/characters32/pau/pau_small.png"
SCALE = 3  # 36 px frames -> 108 px on screen


def data_uri(img: Image.Image) -> str:
    buf = io.BytesIO()
    img.save(buf, "PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()


def sheet() -> tuple[str, int, int]:
    frames = [Image.open(f).convert("RGBA") for f in FRAMES]
    w, h = frames[0].size
    out = Image.new("RGBA", (w * len(frames), h))
    for i, f in enumerate(frames):
        out.paste(f, (i * w, 0))
    return data_uri(out), w, h


def block() -> str:
    alif, fw, fh = sheet()
    pau = data_uri(Image.open(PAU).convert("RGBA"))
    n = len(FRAMES)
    aw, ah = fw * SCALE, fh * SCALE
    css = f"""
#status{{background:transparent!important;z-index:2!important}}
#status-progress,#status-splash{{display:none!important}}
#muat{{position:fixed;inset:0;z-index:1;background:radial-gradient(ellipse at 50% 40%,#2c3550 0%,#1b2030 70%);display:flex;flex-direction:column;align-items:center;justify-content:center;font-family:'Trebuchet MS',Verdana,sans-serif;color:#f5e6c8;transition:opacity .7s ease;pointer-events:none}}
#muat.habis{{opacity:0}}
#muat .logo{{font:900 clamp(34px,7vw,72px)/1 'Trebuchet MS',Verdana,sans-serif;letter-spacing:4px;color:#f3c64b;text-shadow:0 4px 0 #8a5a2e,0 8px 18px rgba(0,0,0,.5);margin-bottom:clamp(40px,9vh,90px)}}
#muat .jalan{{position:relative;width:min(640px,80vw);height:{ah + 30}px}}
#muat .rel{{position:absolute;left:0;right:0;bottom:0;height:18px;border-radius:10px;background:#3a2a1c;border:3px solid #c99a4a;box-shadow:inset 0 3px 0 rgba(0,0,0,.35);overflow:hidden}}
#muat .isi{{height:100%;width:0;background:repeating-linear-gradient(-45deg,#f3c64b 0 14px,#e8a93a 14px 28px);background-size:40px 100%;animation:jalur .8s linear infinite}}
@keyframes jalur{{to{{background-position:40px 0}}}}
#muat .alif{{position:absolute;left:0;bottom:14px;width:{aw}px;height:{ah}px;margin-left:-{aw // 2}px;background:url({alif}) 0 0/{aw * n}px {ah}px;image-rendering:pixelated;animation:lari .6s steps({n}) infinite}}
@keyframes lari{{to{{background-position:-{aw * n}px 0}}}}
#muat .pau{{position:absolute;left:0;bottom:22px;width:48px;height:48px;margin-left:{aw // 2}px;background:url({pau}) 0 0/48px 48px;image-rendering:pixelated;animation:lompat .45s ease-in-out infinite alternate}}
@keyframes lompat{{from{{transform:translateY(0) scale(1.08,.92)}}to{{transform:translateY(-34px) scale(.95,1.05)}}}}
#muat .peratus{{margin-top:14px;font-weight:700;font-size:18px;color:#f3c64b}}
#muat .tip{{margin-top:10px;font-size:clamp(14px,2.2vw,18px);opacity:.85;min-height:1.4em;transition:opacity .4s;text-align:center;padding:0 16px}}
"""
    js = """
(function(){var TIPS=['Alif tengah kejar Pau...','Tip: Klik Pau bila buntu, dia bagi petunjuk.','Tip: Jawab betul cubaan pertama, dapat lebih EXP.','Tip: Buka Beg Alif untuk Jalan Pintas.','Tip: Gelanggang: jawab cepat, serang kuat!'];
function go(){var d=document,m=d.createElement('div');m.id='muat';m.innerHTML='<div class="logo">EXPLO-STORY</div><div class="jalan"><div class="rel"><div class="isi"></div></div><div class="alif"></div><div class="pau"></div></div><div class="peratus">0%</div><div class="tip"></div>';d.body.appendChild(m);
var isi=m.querySelector('.isi'),alif=m.querySelector('.alif'),pau=m.querySelector('.pau'),per=m.querySelector('.peratus'),tip=m.querySelector('.tip'),t=0,shown=0,cur=0,fake=0,done=0;
tip.textContent=TIPS[0];setInterval(function(){tip.style.opacity=0;setTimeout(function(){t=(t+1)%TIPS.length;tip.textContent=TIPS[t];tip.style.opacity=.85},400)},2800);
var timer=setInterval(function(){var s=d.getElementById('status'),p=d.getElementById('status-progress');
if(!s||!s.isConnected){if(!done){done=1;shown=100;setTimeout(function(){m.className='habis';setTimeout(function(){clearInterval(timer);m.remove()},800)},600)}draw();return}
var v=0;if(p&&p.max>0&&p.value>0){v=Math.min(100,p.value/p.max*100)}else{fake=Math.min(95,fake+(95-fake)*0.02);v=fake}
var n=d.getElementById('status-notice');if(n&&n.style.display!=='none'&&n.textContent){m.style.opacity=.25}
shown=Math.max(shown,v);draw()},50);
function draw(){cur+=(shown-cur)*0.12;if(shown-cur<0.2)cur=shown;var w=cur.toFixed(1)+'%';isi.style.width=w;alif.style.left=w;pau.style.left=w;per.textContent=Math.round(shown)+'%'}}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',go);else go()})();
"""
    css = " ".join(line.strip() for line in css.strip().splitlines())
    js = "".join(line.strip() for line in js.strip().splitlines())
    return f"<!--muat--><style>{css}</style><script>{js}</script><!--/muat-->"


def main() -> None:
    text = PRESETS.read_text(encoding="utf-8")
    m = re.search(r'^html/head_include="(.*)"(?=\r?$)', text, re.M)
    if not m:
        raise SystemExit("html/head_include not found in export_presets.cfg")
    # the cfg value is an escaped string: \" for quotes, \\ for backslashes
    value = re.sub(r"<!--muat-->.*<!--/muat-->", "", m.group(1))
    new = block().replace("\\", "\\\\").replace('"', '\\"')
    line = 'html/head_include="' + value + new + '"'
    text = text[: m.start()] + line + text[m.end():]
    PRESETS.write_text(text, encoding="utf-8")
    print("loading screen written:", len(new), "chars")


if __name__ == "__main__":
    main()
