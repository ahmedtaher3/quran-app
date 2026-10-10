"""Build one review packet per sura: each ayah's words + three tafsirs.

usage: python3 build_packets.py <project_root> <sources_dir> <out_dir>
sources_dir holds mukhtasar.json and saadi.json ("sura:aya" -> text);
the Muyassar text comes from assets/ayah.json.
"""
import json, os, sys

root, src, out = sys.argv[1:4]
os.makedirs(out, exist_ok=True)
ayat = json.load(open(f"{root}/assets/ayah.json"))
words = json.load(open(f"{root}/assets/kalemat.json"))
mk = json.load(open(f"{src}/mukhtasar.json"))
sd = json.load(open(f"{src}/saadi.json"))

by_ayah = {}
for w in words:
    if w["char_type"] == "word":
        by_ayah.setdefault(w["ayaID"], []).append(w)

last_saadi = {}
for s in range(1, 115):
    packet = []
    for v in (x for x in ayat if x["sura"] == s):
        key = f"{s}:{v['ayaNumber']}"
        # Sa'di groups some ayat; the text sits on the group's first ayah
        saadi = sd.get(key) or last_saadi.get(s, "")
        if key in sd:
            last_saadi[s] = sd[key]
        packet.append({
            "key": key,
            "text": v["text"],
            "muyassar": v.get("tafsir") or "",
            "mukhtasar": mk.get(key, ""),
            "saadi": saadi[:2500],
            "words": [[w["id"], w["text"], (w.get("code_v3") or "").strip()]
                      for w in by_ayah.get(v["id"], [])],
        })
    json.dump(packet, open(f"{out}/{s:03d}.json", "w"), ensure_ascii=False, indent=0)
print("ok")
