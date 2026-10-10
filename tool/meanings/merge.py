"""Validate reviewed meanings and write them into assets/kalemat.json.

usage: python3 merge.py <project_root> <packets_dir> <decisions_dir>
                        [--check] [--chunk <chunk.json>]

Decision files (any *.json in decisions_dir) are lists of:
  {"id": word_id, "status": "ok"|"fix"|"add"|"drop",
   "meaning": "...", "src": "muyassar"|"mukhtasar"|"saadi", "quote": "..."}
- ok   : existing code_v3 meaning confirmed by the source
- fix  : existing meaning replaced by the source's meaning
- add  : word had no meaning, source gives one
- drop : existing meaning removed (quote explains why)
Every decision needs a quote that appears verbatim (ignoring harakat,
punctuation and spacing) in that ayah's text for the named source.
Every word that already has a code_v3 meaning must be decided.
--chunk <file>: only validate the decision file with the same name and
                only require coverage for that chunk's ayat.
Nothing is written unless everything passes (and --check is absent).
"""
import csv, json, os, re, sys

root, packets, decisions = sys.argv[1:4]
check_only = "--check" in sys.argv
chunk = sys.argv[sys.argv.index("--chunk") + 1] if "--chunk" in sys.argv else None
# --complete-only: write just the suras whose existing meanings are all decided
complete_only = "--complete-only" in sys.argv
SRC = {"muyassar", "mukhtasar", "saadi"}
MARKS = re.compile(r"[ؐ-ًؚ-ٰٟۖ-ۭـ{}«»\"'()\[\]،,.؛;:!?؟\-–—…\s]")


def norm(s):
    s = MARKS.sub("", s or "")
    return (s.replace("أ", "ا").replace("إ", "ا").replace("آ", "ا").replace("ٱ", "ا")
             .replace("ى", "ي").replace("ة", "ه"))


ayah_of, text_of, existing = {}, {}, {}
for f in sorted(os.listdir(packets)):
    for a in json.load(open(f"{packets}/{f}")):
        for wid, text, old in a["words"]:
            ayah_of[wid], text_of[wid] = a, text
            if old:
                existing[wid] = old

files = sorted(x for x in os.listdir(decisions) if x.endswith(".json"))
if chunk:
    files = [x for x in files if x == os.path.basename(chunk)]
    must_cover = {w[0] for a in json.load(open(chunk)) for w in a["words"] if w[2]}

errors, merged, rows, seen = [], {}, [], set()
for f in files:
    for d in json.load(open(f"{decisions}/{f}")):
        wid, st = d.get("id"), d.get("status")
        where = f"{f} word {wid}"
        if wid not in ayah_of:
            errors.append(f"{where}: unknown word id"); continue
        if wid in seen:
            errors.append(f"{where}: decided twice"); continue
        seen.add(wid)
        a = ayah_of[wid]
        where += f" ({a['key']} {text_of[wid]})"
        if st not in {"ok", "fix", "add", "drop"}:
            errors.append(f"{where}: bad status {st}"); continue
        if d.get("src") not in SRC:
            errors.append(f"{where}: bad src {d.get('src')}"); continue
        q = norm(d.get("quote"))
        if len(q) < 4 or q not in norm(a[d["src"]]):
            errors.append(f"{where}: quote not found in {d['src']}: {d.get('quote')!r}"); continue
        if st == "add" and wid in existing:
            errors.append(f"{where}: 'add' on a word that already has a meaning (use ok/fix)"); continue
        if st in {"ok", "fix", "drop"} and wid not in existing:
            errors.append(f"{where}: '{st}' on a word with no existing meaning (use add)"); continue
        if st in {"fix", "add"} and not (d.get("meaning") or "").strip():
            errors.append(f"{where}: empty meaning"); continue
        meaning = existing[wid] if st == "ok" else ("" if st == "drop" else d["meaning"].strip())
        merged[wid] = (meaning, d["src"])
        rows.append([a["key"], text_of[wid], st, existing.get(wid, ""), meaning, d["src"], d["quote"]])

if not chunk:
    touched = {ayah_of[w]["key"].split(":")[0] for w in seen}
    must_cover = {w for w in existing if ayah_of[w]["key"].split(":")[0] in touched}
missing = must_cover - seen
if complete_only:
    partial = {ayah_of[w]["key"].split(":")[0] for w in missing}
    keep = lambda w: ayah_of[w]["key"].split(":")[0] not in partial
    merged = {w: v for w, v in merged.items() if keep(w)}
    rows = [r for r in rows if r[0].split(":")[0] not in partial]
    print(f"skipping {len(partial)} partially reviewed suras")
    missing = set()
for wid in sorted(missing):
    errors.append(f"word {wid} ({ayah_of[wid]['key']} {text_of[wid]}): existing meaning not reviewed")

print(f"files: {len(files)}  decisions: {len(merged)}  errors: {len(errors)}")
for e in [x for x in errors if "not reviewed" not in x][:80] + [f"... {sum("not reviewed" in x for x in errors)} not-yet-reviewed (chunks in progress)"]:
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
