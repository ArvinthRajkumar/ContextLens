# Try a sample videos

Synthetic test videos for judges and testers, with fictional brands and people. The scripts, the generator and the manifest live here; the videos live only in `gs://contextlens-tekken-samples`.

| File | What it is |
|---|---|
| `scripts.json` | Every spoken line, voice, scene color, overlay and the declaration for each generated sample |
| `generate.py` | Cloud Text-to-Speech (en-IN Chirp 3 HD) for the speech, ffmpeg for everything else; writes `out/` and fills durations, sizes and resolutions into `samples.json` |
| `samples.json` | The manifest the API serves. Ids not listed here are rejected. `expect` and `allow` are for `verify.py` only; the API strips them |
| `verify.py` | Runs each sample through the deployed pipeline and checks it raises its intended flags (and nothing outside `allow`) |

`supplements_hinglish.mp4` was made earlier with Gemini TTS over stock footage and is kept as it is; its generator was not saved, so only its manifest entry is here.

## Rebuild

```sh
cd backend
FFMPEG=<ffmpeg> .venv/Scripts/python.exe ../tool/samples/generate.py           # or list ids
FFMPEG=<ffmpeg> .venv/Scripts/python.exe ../tool/samples/verify.py             # costs about USD 0.05 per sample
gcloud storage cp ../tool/samples/out/*.mp4 ../tool/samples/out/*.jpg ../tool/samples/samples.json gs://contextlens-tekken-samples/
```

Put `supplements_hinglish.mp4` (and a thumbnail) in `out/` before uploading if the bucket needs it again. The API caches the manifest for five minutes.

## Rules for new samples

- 9:16, 25 to 50 s, under 20 MB; a borrowed-clip source can be longer and landscape.
- Fictional brands only. Check that the name has no real product behind it: a real brand pulls in fact checks about that company (that is why the clean control is "Kaapiwren", not "Brewbird").
- "Synthetic test video" in the metadata and on screen.
- Run `verify.py` and keep a sample only if it passes.
