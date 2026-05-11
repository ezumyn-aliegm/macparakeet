# Music & Sound Design (`public/audio/music/`)

The brand film picks up audio from this directory at render time. The
files are **not tracked** (gitignored) — they come from royalty-free
libraries and are sourced once per project.

## Required files

| File | Used by | What it is | Length |
|---|---|---|---|
| `brand-track.wav` | `BrandShow30` (audioReady=true) | Music bed for the full 30s film | exactly 30 s |
| `brand-track-15s.wav` | `BrandShow15Portrait` | 15 s edit of the same bed (or separate track) | exactly 15 s |
| `logo-sting.wav` | both BrandShow variants | Single chime / synth swell at the logo reveal | 2–4 s |

If the files are missing and the composition is rendered with
`audioReady=false` (default), the brand film renders silently — no
errors, no broken sequences. Flip `audioReady=true` in the render
command (`npm run render:brand-audio`) once the files are in place.

## Brand voice for the music

The film leans Warhol-meets-quiet-confidence. The track should:

- **BPM**: 110–125 — energetic enough to feel alive, calm enough to feel
  considered. Avoid anything over 130 BPM.
- **Texture**: minimal electronic / indie ambient. Sparse drums, clean
  synths, *no vocals*. Think Tycho, Bonobo's calmer cuts, Nils Frahm's
  more rhythmic moments.
- **Arc**: a quiet first ~2 seconds (to match the intro mark fade-in),
  builds through the grid section, then resolves / fades around 20 s
  (where the fade-to-ink begins). A drop-style track with a quiet outro
  is ideal.
- **Mood**: confident, modern, slightly playful. The Pop palette is
  playful; the music should echo without becoming kitsch.

**Avoid**: heavy bass, distorted guitars, cinematic strings, anything
that sounds like a movie trailer.

## Brand voice for the sting

Single sound event that hits the moment the logo reveals (frame 1380 of
BrandShow30, roughly 0:23):

- One synth note, a soft chime, or a calm bell-like tone
- Length 2–4 seconds with a long natural decay
- Should *resolve* — not a stinger that demands a follow-up
- Adds weight to the logo without being loud

**Avoid**: notification dings, sword unsheathing sounds, cinematic
"booms," anything percussive enough to startle.

## Recommended search queries

### Pixabay (free, attribution optional, broad library)

- <https://pixabay.com/music/search/minimal%20electronic/> → filter by
  3-min or shorter, ~120 BPM range
- <https://pixabay.com/music/search/ambient%20chill/> → minimal indie
  electronic
- Sound effects for the sting:
  <https://pixabay.com/sound-effects/search/synth%20chime/> or
  `/search/soft%20bell/`

### Mixkit (free, attribution-required for some)

- <https://mixkit.co/free-stock-music/tag/electronic/>
- <https://mixkit.co/free-stock-music/tag/minimal/>
- Sound effects: <https://mixkit.co/free-sound-effects/notification/>
  → look for "soft notification" / "subtle chime"

### Free Music Archive (Creative Commons)

- <https://freemusicarchive.org/genre/Electronic/> → filter for CC-BY or
  CC0 licenses, electronic/minimal/ambient

### If you have a Suno subscription (~$8/mo)

Prompt suggestion for a 30 s custom track:

> Minimal electronic instrumental, 120 BPM, sparse clean synths, soft
> kick drum on every beat 8–22 s, no vocals, quiet intro and outro,
> modern indie ambient mood, confident but considered, 30 seconds total

## Editing notes

If a track is longer than 30 s, trim or fade it to fit. ffmpeg cookbook:

```sh
# Trim to exactly 30s and fade the last 1.5s out
ffmpeg -i source.mp3 -ss 0 -t 30 -af "afade=t=out:st=28.5:d=1.5" -c:a pcm_s16le brand-track.wav

# 15s edit for portrait variant
ffmpeg -i source.mp3 -ss 0 -t 15 -af "afade=t=out:st=13.5:d=1.5" -c:a pcm_s16le brand-track-15s.wav
```

For the sting, target 2–3 s with a long natural decay tail:

```sh
ffmpeg -i raw-chime.mp3 -t 3 -af "afade=t=out:st=2.0:d=1.0" -c:a pcm_s16le logo-sting.wav
```
