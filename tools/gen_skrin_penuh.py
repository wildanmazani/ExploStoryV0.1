"""Web page: the "Skrin Penuh" button for phones, and the iPhone install guide.

Android and iPad Safari can go fullscreen from a tap. iPhone browsers cannot
(Safari and Chrome alike), so there the button opens a step-by-step guide to
put the game on the Home Screen, where it runs fullscreen. The steps name the
exact button for the browser in use: Safari, Chrome, or an in-app browser
(WhatsApp, Telegram...) that has no Add to Home Screen at all.

Writes the block into html/head_include in export_presets.cfg, between
<!--skrin--> and <!--/skrin-->; rerunning replaces it and keeps the rest.

    python tools/gen_skrin_penuh.py
"""
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
PRESETS = ROOT / "export_presets.cfg"

# the Share icon (a box with an arrow going up) and the Add icon (a plus in a box)
KONGSI = ('<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">'
          '<path d="M12 15V3"/><path d="M8 7l4-4 4 4"/><path d="M7 11H5v10h14V11h-2"/></svg>')
TAMBAH = ('<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">'
          '<rect x="3" y="3" width="18" height="18" rx="4"/><path d="M12 8v8M8 12h8"/></svg>')

CSS = """
#skrin-penuh{position:fixed;top:8px;left:50%;transform:translateX(-50%);z-index:2147483646;padding:10px 18px;font:bold 16px sans-serif;color:#fff;background:#8a5a2e;border:2px solid #f3c64b;border-radius:10px;touch-action:manipulation;white-space:nowrap}
#pasang{position:fixed;inset:0;z-index:2147483647;background:rgba(12,15,24,.94);overflow-y:auto;-webkit-overflow-scrolling:touch;touch-action:pan-y;display:flex;font-family:'Trebuchet MS',Verdana,sans-serif;color:#f5e6c8;-webkit-user-select:none;user-select:none}
#pasang .kad{margin:auto;width:min(680px,94vw);padding:52px 16px 16px;box-sizing:border-box}
#pasang h2{margin:0 0 4px;font-size:22px;color:#f3c64b;text-align:center}
#pasang .sub{margin:0 0 12px;font-size:15px;text-align:center;opacity:.9}
#pasang .amaran{background:#5a2320;border:2px solid #e2725b;border-radius:12px;padding:10px 12px;margin-bottom:12px;font-size:15px;line-height:1.4;text-align:center}
#pasang .amaran button{margin-top:8px}
#pasang ol{list-style:none;margin:0;padding:0;display:grid;gap:8px}
#pasang li{display:flex;align-items:center;gap:12px;background:#2a3147;border:2px solid #4a5578;border-radius:12px;padding:10px 12px;font-size:16px;line-height:1.35}
#pasang .no{flex:none;width:34px;height:34px;border-radius:50%;background:#f3c64b;color:#2a1c0e;font-weight:700;font-size:18px;display:flex;align-items:center;justify-content:center}
#pasang .ikon{flex:none;width:44px;height:44px;border-radius:10px;background:#fff;color:#0a7aff;display:flex;align-items:center;justify-content:center}
#pasang .ikon svg{width:28px;height:28px}
#pasang .ikon.app{background:#8a5a2e;color:#f3c64b;font-weight:700;font-size:20px;border:2px solid #f3c64b;box-sizing:border-box}
#pasang b{color:#fff}
#pasang small{display:block;font-size:13px;opacity:.8;margin-top:2px}
#pasang .nota{margin:10px 0 0;font-size:14px;text-align:center;opacity:.85}
#pasang button{font:bold 16px sans-serif;color:#fff;background:#8a5a2e;border:2px solid #f3c64b;border-radius:10px;padding:10px 22px;touch-action:manipulation}
#pasang #pasang-tutup{position:fixed;top:8px;right:8px;padding:8px 16px;z-index:1}
@media (orientation:landscape) and (max-height:520px){#pasang ol{grid-template-columns:1fr 1fr}#pasang li{font-size:14px;padding:8px 10px;gap:9px}#pasang h2{font-size:19px}#pasang .sub{margin-bottom:8px;font-size:14px}}
"""

JS = """
(function(){var d=document,e=d.documentElement,b,g,ua=navigator.userAgent;
if(!(matchMedia('(pointer: coarse)').matches||'ontouchstart' in window))return;
if(matchMedia('(display-mode: standalone)').matches||navigator.standalone)return;
var r=e.requestFullscreen||e.webkitRequestFullscreen,can=!!(r&&(d.fullscreenEnabled||d.webkitFullscreenEnabled));
var pad=/iPad/.test(ua)||(/Macintosh/.test(ua)&&navigator.maxTouchPoints>1),alat=pad?'iPad':'iPhone';
var chrome=/CriOS/.test(ua),safari=!chrome&&/Safari\\//.test(ua)&&/Version\\//.test(ua)&&!/FxiOS|EdgiOS|OPiOS|OPT\\/|DuckDuckGo|GSA\\//.test(ua);
function on(){return d.fullscreenElement||d.webkitFullscreenElement}
function show(){if(b)b.style.display=on()||g?'none':'block'}
function lock(){if(screen.orientation&&screen.orientation.lock)screen.orientation.lock('landscape').catch(function(){})}
function tutup(){if(g){g.remove();g=null;show()}}
function salin(ev){var t=ev.currentTarget;function ok(){t.textContent='Pautan disalin \\u2713'}
if(navigator.clipboard&&navigator.clipboard.writeText)navigator.clipboard.writeText(location.href).then(ok,function(){prompt('Salin pautan ini:',location.href)});else prompt('Salin pautan ini:',location.href)}
function panduan(){if(g)return;
var mana=chrome?'Ada di hujung kanan bar alamat Chrome.':(pad?'Ada di bahagian atas Safari.':'Ada di bar Safari. Tak nampak? Tekan \\u2022\\u2022\\u2022 dulu.');
var h='<div class="kad"><h2>Cara main di '+alat+'</h2><p class="sub">Letak game di Skrin Utama dulu. Buat sekali saja.</p>';
if(!chrome&&!safari)h+='<div class="amaran">Pelayar ini tak boleh pasang game.<br>Salin pautan, buka <b>Safari</b>, tampal di situ, kemudian ikut langkah di bawah.<br><button id="pasang-salin">Salin pautan</button></div>';
h+='<ol><li><span class="no">1</span><span class="ikon">__KONGSI__</span><span>Tekan butang <b>Kongsi</b> (Share).<small>'+mana+'</small></span></li>'
+'<li><span class="no">2</span><span class="ikon">__TAMBAH__</span><span>Scroll ke bawah, tekan <b>Add to Home Screen</b>.<small>Dalam BM: Tambah ke Skrin Utama.</small></span></li>'
+'<li><span class="no">3</span><span class="ikon" style="font:bold 15px sans-serif">Add</span><span>Tekan <b>Add</b> (Tambah) di penjuru atas kanan.</span></li>'
+'<li><span class="no">4</span><span class="ikon app">E</span><span>Tutup pelayar. Tekan ikon <b>Explo-Story</b> di Skrin Utama.<small>Game terus buka skrin penuh.</small></span></li></ol>'
+'<p class="nota">Dah ada akaun? Log masuk semula, kemajuan kekal.</p></div><button id="pasang-tutup">\\u2715 Tutup</button>';
g=d.createElement('div');g.id='pasang';g.innerHTML=h;d.body.appendChild(g);
g.querySelector('#pasang-tutup').addEventListener('click',tutup);
var s=g.querySelector('#pasang-salin');if(s)s.addEventListener('click',salin);
show()}
function tap(ev){ev.preventDefault();ev.stopPropagation();
if(can){var p=r.call(e,{navigationUI:'hide'});if(p&&p.then)p.then(lock,function(){});else lock()}else panduan()}
d.addEventListener('fullscreenchange',show);d.addEventListener('webkitfullscreenchange',show);
function go(){b=d.createElement('button');b.id='skrin-penuh';b.textContent=can?'\\u26F6 Skrin Penuh':'\\u2B07 Cara main di '+alat;
b.addEventListener('click',tap);d.body.appendChild(b);show()}
if(d.readyState==='loading')d.addEventListener('DOMContentLoaded',go);else go()})();
"""

OLD = re.compile(r"<script>\(function\(\)\{var d=document,e=d\.documentElement,b;.*?</script>")  # the block before it had markers


def block() -> str:
    css = " ".join(line.strip() for line in CSS.strip().splitlines())
    js = "".join(line.strip() for line in JS.strip().splitlines())
    js = js.replace("__KONGSI__", KONGSI).replace("__TAMBAH__", TAMBAH)  # no ' in them: safe in a '...' string
    return f"<!--skrin--><style>{css}</style><script>{js}</script><!--/skrin-->"


def main() -> None:
    text = PRESETS.read_text(encoding="utf-8")
    m = re.search(r'^html/head_include="(.*)"(?=\r?$)', text, re.M)
    if not m:
        raise SystemExit("html/head_include not found in export_presets.cfg")
    # the cfg value is an escaped string: \" for quotes, \\ for backslashes
    new = block().replace("\\", "\\\\").replace('"', '\\"')
    value = m.group(1)
    if "<!--skrin-->" in value:
        value = re.sub(r"<!--skrin-->.*<!--/skrin-->", lambda _: new, value)
    elif OLD.search(value):
        value = OLD.sub(lambda _: new, value, count=1)
    else:
        raise SystemExit("no fullscreen block found in html/head_include")
    text = text[: m.start()] + 'html/head_include="' + value + '"' + text[m.end():]
    PRESETS.write_text(text, encoding="utf-8")
    print("fullscreen button + iPhone guide written:", len(new), "chars")


if __name__ == "__main__":
    main()
