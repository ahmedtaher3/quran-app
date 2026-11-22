# Adhan voices

The app reads `catalog.json` from this folder on `main`
(`https://raw.githubusercontent.com/ahmedtaher3/quran-app/main/adhan/catalog.json`)
and lists its voices under Prayer settings → صوت الأذان. A voice added or
removed here shows up for everyone without an app update.

Only add recordings the app has the right to distribute: your own recording
with the muezzin's written consent, a purchased license that covers apps, or
a public-domain / CC0 source. Removing an entry hides it at once; phones that
already downloaded it keep playing their copy.

## Adding a voice

1. Put the mp3 in `adhan/audio/` (served from `raw.githubusercontent.com`, as
   below) or anywhere else stable over HTTPS, such as a GitHub Release.
2. Add an entry to `items`:

```json
{
  "id": "makkah",
  "name": "أذان الحرم المكي",
  "place": "مكة المكرمة",
  "url": "https://raw.githubusercontent.com/ahmedtaher3/quran-app/main/adhan/audio/makkah.mp3",
  "size": 1468000,
  "seconds": 192,
  "fajrUrl": "https://raw.githubusercontent.com/ahmedtaher3/quran-app/main/adhan/audio/makkah_fajr.mp3",
  "fajrSize": 1530000
}
```

- `id`: lowercase letters, digits, `_` or `-`; never reuse one for a different
  recording (phones key their downloaded file by it).
- `size` (bytes) and `seconds`: shown in the list; optional.
- `fajrUrl` / `fajrSize`: optional Fajr recording (with «الصلاة خير من النوم»).
  Without it Fajr uses `url`.
- `credit`: author and license, shown under the voice. Required for CC BY and
  CC BY-SA recordings (e.g. `"ejaz215 · CC BY 3.0"`); keep the full source
  links in the Sources table below.

Keep files short and light: a mono 64–96 kbps mp3 of a full adhan is about
1.5 MB.

To prepare a file the way the current ones were (mono, even loudness, short
fades, ~96 kbps):

```sh
ffmpeg -ss <start> -to <end> -i source -ac 1 \
  -af "highpass=f=90,loudnorm=I=-16:TP=-1.5:LRA=11,afade=t=in:d=0.5,afade=t=out:st=<length-2>:d=2" \
  -codec:a libmp3lame -b:a 96k adhan/audio/<id>.mp3
```

## Sources

| File | Recording | Author | License | Changes |
|---|---|---|---|---|
| `audio/cairo_khan_el_khalili.mp3` | [Call to prayer (Khan El Khalili rooftop)](https://freesound.org/people/3bagbrew/sounds/511003/), Cairo | 3bagbrew | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | 1:30–5:16 kept, mono, loudness-normalized, fades |
| `audio/azeez.mp3` | [The Adhan - Muslim Call to Prayer - Aaqib Azeez](https://commons.wikimedia.org/wiki/File:The_Adhan_-_Muslim_Call_to_Prayer_-_Aaqib_Azeez.mp3) | Atcovi | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) | mono, loudness-normalized, fades; this file is shared under CC BY-SA 4.0 too |

Looked at and left out (2026-11-22): the Prophet's Mosque recording on
Wikimedia (`33937_ejaz215_…`, marked CC BY 3.0) sounds like a broadcast and
was removed from Freesound, so the uploader's right to license it is unclear;
Jumeirah Mosque, Dubai (Freesound 144431, CC0) was dropped by the owner;
Quseir (Freesound 555065, CC0) is too faint under the sea noise.
