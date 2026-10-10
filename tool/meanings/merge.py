"""Validate reviewed meanings and write them into assets/kalemat.json.

usage: python3 merge.py <project_root> <packets_dir> <decisions_dir> [--check]

A decisions file (NNN.json, one per sura) is a list of:
  {"id": word_id, "status": "ok"|"fix"|"add"|"drop",
   "meaning": "...", "src": "muyassar"|"mukhtasar"|"saadi", "quote": "..."}
- ok   : existing code_v3 meaning confirmed by the source
- fix  : existing meaning replaced by the source's meaning
- add  : word had no meaning, source gives one
- drop : existing meaning removed (quote explains why)
Every decision must carry a quote that appears verbatim (ignoring harakat
and spacing) in that ayah's text for the named source. Every word that
already has a code_v3 meaning must be decided. Anything failing is reported
and NOT written.
"""
import csv, json, os, re, sys

root, packets, decisions = sys.argv[1:4]
check_only = "--check" in sys.argv
SRC = {"muyassar", "mukhtasar", "saadi"}
MARKS = re.compile(r"[ؐ-ًؚ-ٰٟۖ-ۭـ{}«»\"'()\[\]،,.؛:!?؟\s]")


def norm(s):
    s = MARKS.sub("", s)
    return (s.replace("أ", "ا").replace("إ", "ا").replace("آ", "ا").replace("ٱ", "ا")
             .replace("ى", "ي").replace("ة", "ه"))


errors, merged, rows = [], {}, []
for f in sorted(os.listdir(decisions)):
    if not f.endswith(".json"):
        continue
    sura = f[:3]
    packet = json.load(open(f"{packets}/{sura}.json"))
    word_ayah = {w[0]: a for a in packet for w in a["words"]}
    word_text = {w[0]: w[1] for a in packet for w in a["words"]}
    existing = {w[0]: w[2] for a in packet for w in a["words"] if w[2]}
    seen = set()
    for d in json.load(open(f"{decisions}/{f}")):
        wid, st = d.get("id"), d.get("status")
        where = f"{sura} word {wid}"
        if wid not in word_ayah:
            errors.append(f"{where}: unknown word id"); continue
        seen.add(wid)
        a = word_ayah[wid]
        if st not in {"ok", "fix", "add", "drop"}:
            errors.append(f"{where}: bad status {st}"); continue
        if d.get("src") not in SRC:
            errors.append(f"{where}: bad src {d.get('src')}"); continue
        q = norm(d.get("quote", ""))
        if len(q) < 4 or q not in norm(a[d["src"]]):
            errors.append(f"{where} ({a['key']}): quote not found in {d['src']}: {d.get('quote')!r}"); continue
        if st == "add" and existing.get(wid):
            errors.append(f"{where}: 'add' on a word that already has a meaning"); continue
        if st in {"ok", "fix", "drop"} and not existing.get(wid):
            errors.append(f"{where}: '{st}' on a word with no existing meaning"); continue
        if st in {"fix", "add"} and not d.get("meaning", "").strip():
            errors.append(f"{where}: empty meaning"); continue
        meaning = existing[wid] if st == "ok" else ("" if st == "drop" else d["meaning"].strip())
        merged[wid] = (meaning, d["src"])
        rows.append([a["key"], word_text[wid], st, existing.get(wid, ""), meaning, d["src"], d["quote"]])
    for wid in existing:
        if wid not in seen:
            errors.append(f"{sura} word {wid} ({word_ayah[wid]['key']} {word_text[wid]}): existing meaning not reviewed")

print(f"decisions: {len(merged)}  errors: {len(errors)}")
for e in errors[:60]:
    print("  ", e)
if errors or check_only:
    sys.exit(1 if errors else 0)

path = f"{root}/assets/kalemat.json"
words = json.load(open(path))
for w in words:
    if w["id"] in merged:
        w["meaning"], w["meaning_src"] = merged[w["id"]]
# same layout as the original file (sorted keys, 4-space indent) so diffs stay readable
open(path, "w").write(json.dumps([dict(sorted(w.items())) for w in words],
                                 ensure_ascii=False, indent=4))

os.makedirs(f"{root}/tool/meanings/review", exist_ok=True)
with open(f"{root}/tool/meanings/review/decisions.csv", "w", newline="") as fh:
    c = csv.writer(fh)
    c.writerow(["ayah", "word", "status", "old_meaning", "new_meaning", "source", "quote"])
    c.writerows(sorted(rows, key=lambda r: [int(x) for x in r[0].split(":")]))
print("written")
