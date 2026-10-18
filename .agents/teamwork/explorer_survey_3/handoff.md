# Handoff Report — Explorer 3: Video Packaging & Hook Design Specification

## Executive Summary
This report delivers the complete survey of destination directories, empirical video stream measurements, viral hook overlay design strategy (Underdog / Hidden Power themes in Turkish and English), and the exact architectural specification for `README_VIDEOLAR.md` for the mobile game **Kırmataş** (`com.kaunos.kirmatas`).

---

## 1. Observation

### 1.1 Target Destination Directory Inspection
Direct inspection of `C:\Users\USER\Desktop\Kirmatas_Reklam_Videolari` and subfolders:
- **Root Directory**: `C:\Users\USER\Desktop\Kirmatas_Reklam_Videolari` exists.
- **Master Files**: Contains exactly **5 master MP4 files**, all valid, playable, high-bitrate vertical videos (>1MB, ranging from 7.74 MB to 30.78 MB).
- **Scenes Directory**: `C:\Users\USER\Desktop\Kirmatas_Reklam_Videolari\Scenes` does **NOT** exist yet. It must be created (`mkdir`) during Milestone 2 to house the individual scene clips.

### 1.2 Master Video Empirical Metadata Table
Measured directly via FFprobe (`ffprobe version 9.0.2-full_build`):

| # | Master File Name | File Size (Bytes) | Size (MB) | Duration (s) | Resolution | Aspect Ratio | FPS | Video Codec | Audio Codec | Bitrate |
|---|---|---|---|---|---|---|---|---|---|---|
| **01** | `01_Ilk_Drama_Reklami.mp4` | 10,982,778 | 10.47 MB | 39.66s | 720x1280 | 9:16 | 25.0 fps | H.264 (High) | AAC (44.1kHz stereo) | 2,215 kb/s |
| **02** | `02_Penthouse_Kasli_Karpuz_ve_Dolgun_Kizlar.mp4` | 32,279,715 | 30.78 MB | 32.17s | 720x1280 | 9:16 | 24.0 fps | H.264 (High) | AAC (48.0kHz stereo) | 8,028 kb/s |
| **03** | `03_Sinematik_Malikane_Yuzlesmesi.mp4` | 8,507,066 | 8.11 MB | 30.21s | 720x1280 | 9:16 | 25.0 fps | H.264 (High) | AAC (44.1kHz stereo) | 2,253 kb/s |
| **04** | `04_500_Tuglali_Kasa_Tuzagi_Kurtarma.mp4` | 11,097,041 | 10.58 MB | 38.21s | 720x1280 | 9:16 | 25.0 fps | H.264 (High) | AAC (44.1kHz stereo) | 2,324 kb/s |
| **05** | `05_YuzdeYuz_Meyve_Cekici_Strawberry_Diva_Acilis.mp4` | 8,116,701 | 7.74 MB | 27.18s | 720x1280 | 9:16 | 25.0 fps | H.264 (High) | AAC (44.1kHz stereo) | 2,389 kb/s |

### 1.3 Video Content & Visual Storyline Inspection
Using FFmpeg frame extraction (`-vframes 1`) and image analysis across timeline points (05s, 15s, 25s, end), the content of the 5 videos was cataloged:
1. **01_Ilk_Drama_Reklami.mp4 (Penthouse Drama & Betrayal)**:
   - *Characters*: Strawberry Diva (angry, luxury red gown, pearl necklace, giant strawberry headdress) vs. Watermelon Girl (lush green wavy hair, watermelon bikini, smug expression).
   - *Setting*: Ultra-modern penthouse living room with pool vista.
   - *Narrative*: Strawberry Diva rages that her status was ruined; Watermelon Girl enters calmly, showing her mobile phone and boasting about her wealth from Kırmataş.
   - *Existing burn-in*: Bottom dialogue subtitles in English ("destroyed", "flag!", "Because last", "Kirmatas for free").
2. **02_Penthouse_Kasli_Karpuz_ve_Dolgun_Kizlar.mp4 (Mythic Relics & Ancient Energy)**:
   - *Characters*: Muscular Watermelon King, Peach Goddess in sparkling green bikini on a bioluminescent mushroom dock, tree etched with glowing ancient runes, and human red-haired maiden before a glowing relic idol.
   - *Setting*: Enchanted rolling green hills, fairy lake pier, mystic woodland, luxury palace stairway.
   - *Narrative*: Epic world-building and forbidden brick-breaking relics that only veteran players can unlock.
3. **03_Sinematik_Malikane_Yuzlesmesi.mp4 (Poolside Mansion Confrontation)**:
   - *Characters*: Strawberry Diva confronting muscular Pineapple Chad relaxing on a poolside lounger, joined by ecstatic Watermelon Girl.
   - *Setting*: Sunny tropical villa pool with palm trees and flowers.
   - *Narrative*: Strawberry Diva demands respect, but Pineapple Chad and Watermelon Girl laugh off her complaints, flexing that true status comes from leaderboard supremacy in Kırmataş.
4. **04_500_Tuglali_Kasa_Tuzagi_Kurtarma.mp4 (500-Brick Vault Trap & Rescue)**:
   - *Characters*: Strawberry damsel trapped on her knees inside a reinforced bank vault with gold bullion stacks and red laser security; Peach girl outside laughing on her smartphone; Juggernaut Watermelon hero arriving to smash the vault open.
   - *Setting*: Underground bank vault sealed with unbreakable 500-brick reinforced doors.
   - *Narrative*: Impossible level rescue dilemma. Only a player with Level 999 brick-smashing power can break through the 500 bricks to rescue the captive.
5. **05_YuzdeYuz_Meyve_Cekici_Strawberry_Diva_Acilis.mp4 (Rags to Riches / Empire Takeover)**:
   - *Characters*: Strawberry Diva weeping in gilded palace ballroom ("I AM RUINED!"), transitioning to Watermelon Diva taking over the entire estate and swimming pool ("This luxury is mine now!").
   - *Setting*: Baroque palace ballroom to sunny luxury resort estate.
   - *Narrative*: Complete reversal of fortune. The snobbish queen loses everything while the underdog ascends to total ownership in a single night of record-breaking gameplay.

### 1.4 System Environment & Rendering Capabilities
- **FFmpeg**: `v9.0.2-full_build` installed at `C:\Users\USER\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-9.0.2-full_build\bin\ffmpeg.exe`. Includes `libfreetype`, `libfribidi`, `libharfbuzz`, `libx264`.
- **Node.js**: `v24.15.0` active in PATH.
- **Fonts Available**:
  - `C:\Windows\Fonts\arialbd.ttf` (Arial Bold — full Turkish UTF-8 character support verified).
  - `C:\Windows\Fonts\impact.ttf` (Impact — classic meme/hook font).
  - `c:\Users\USER\Desktop\KIPKIRMATAS\assets\fonts\Rajdhani-Bold.ttf` (Authentic Kırmataş in-game font).
- **Empirical Test**: A test banner overlay with full Turkish character support (`GİZLİ 999. SEVİYE GÜCÜNÜ KİMSE BİLMİYORDU!`) was rendered onto frame 1 (`test_tr_node.jpg`) and visually confirmed with zero artifacting, crisp anti-aliasing, and perfect positioning.

---

## 2. Logic Chain

1. **Observation 1.1 & 1.2**: All 5 master MP4 files exist in `C:\Users\USER\Desktop\Kirmatas_Reklam_Videolari`, are 720x1280 (9:16 vertical), and range between 27.18s and 39.66s.
   - *Inference*: No re-encoding of base dimensions is needed; preserving native 720x1280 guarantees zero pixel stretching, optimal rendering speed, and standard mobile feed delivery.

2. **Observation 1.3**: Existing dialogue subtitles ("destroyed", "Kirmatas for free") are hardcoded at the bottom of the frame (Y ≈ 1000px to 1150px).
   - *Inference*: Any new viral hook banner MUST be positioned in the top 15% safe area (Y ≈ 60px to 220px). This prevents visual collision with bottom subtitles and aligns with TikTok/Reels UI standards where the top-center is the primary visual hook anchor.

3. **Observation 1.3**: The 5 videos strictly revolve around high-stakes soap-opera mobile drama: Underdog triumphs, sudden wealth flips, hidden Level 999 strength, and impossible 500-brick vault puzzles.
   - *Inference*: The viral hook text overlay strategy must directly amplify these exact narrative beats using high-dopamine bilingual copywriting (Turkish & English) tailored for social media conversion.

4. **Observation 1.4**: FFmpeg with `libfreetype` and `arialbd.ttf` renders Turkish characters (Ğ, Ü, Ş, İ, Ö, Ç) flawlessly when path-escaped (`C\\:/Windows/Fonts/arialbd.ttf`) or driven via Node.js automation.
   - *Inference*: Milestone 3 can generate all 10 social-ready hook overlay variants (5 TR + 5 EN) deterministically in seconds by copying audio (`-c:a copy`) and re-encoding only video with `-crf 18`.

5. **Observation 1.1**: The `Scenes/` folder is missing.
   - *Inference*: Worker for Milestone 2 must create `C:\Users\USER\Desktop\Kirmatas_Reklam_Videolari\Scenes` and archive raw scene clips there.

---

## 3. Caveats

1. **Audio Streams**: The existing audio tracks contain full English dialogue and background sound. Copying audio (`-c:a copy`) preserves 100% original high-fidelity audio without re-compression, but the spoken voice remains English while the hook banners provide the Turkish or English social context.
2. **Top UI Safe Zone**: On TikTok/Shorts, the very top 40px contains status icons (battery, clock). Positioning the banner at `Y=60px` to `Y=200px` guarantees 100% readability on all Android and iOS devices.
3. **Master Files Immutability**: The 5 original files (`01_Ilk_Drama_Reklami.mp4` through `05_YuzdeYuz_Meyve_Cekici_Strawberry_Diva_Acilis.mp4`) must NOT be overwritten. Hook variants must be created with dedicated filenames (e.g. `01_Ilk_Drama_Reklami_Hook_TR.mp4`).

---

## 4. Conclusion & Complete Design Specifications

### 4.1 Viral Hook Overlay Specifications

#### Visual Style Guide
- **Container**: Rounded/sharp black rectangular box (`drawbox=x=30:y=60:w=660:h=130:color=black@0.85:t=fill`)
- **Accent Border**: 3px vibrant electric yellow border (`drawbox=x=30:y=60:w=660:h=130:color=yellow@0.9:t=3`)
- **Line 1 (The Intrigue / Setup)**:
  - Font: `C\:/Windows/Fonts/arialbd.ttf`
  - Color: Pure White (`#FFFFFF`)
  - Size: 34px - 36px
  - Alignment: Horizontally centered `x=(w-text_w)/2`, `y=78`
- **Line 2 (The Punchline / Hidden Power)**:
  - Font: `C\:/Windows/Fonts/arialbd.ttf`
  - Color: High-Visibility Solar Yellow (`#FFE600`)
  - Size: 40px - 44px
  - Alignment: Horizontally centered `x=(w-text_w)/2`, `y=122`

#### Complete Bilingual Hook Matrix (10 Variants)

| Video # | Source Master File | Variant Suffix | Lang | Line 1 Text (Setup) | Line 2 Text (Punchline) | Narrative Theme |
|---|---|---|---|---|---|---|
| **01** | `01_Ilk_Drama_Reklami.mp4` | `_Hook_TR.mp4` | **TR** | `HERKES ONU EZİK SANDI` | `AMA REKORU KIRDI!` | Underdog Revenge & Secret Grind |
| **01** | `01_Ilk_Drama_Reklami.mp4` | `_Hook_EN.mp4` | **EN** | `THEY THOUGHT SHE WAS BROKE...` | `UNTIL LEVEL 999 UNLOCKED!` | Rags to Riches & Secret Wealth |
| **02** | `02_Penthouse_Kasli_Karpuz_ve_Dolgun_Kizlar.mp4` | `_Hook_TR.mp4` | **TR** | `GİZLİ 999. SEVİYE GÜCÜNÜ` | `KİMSE BİLMİYORDU!` | Ancient Mythic Relic & Forbidden Power |
| **02** | `02_Penthouse_Kasli_Karpuz_ve_Dolgun_Kizlar.mp4` | `_Hook_EN.mp4` | **EN** | `HE WAS HIDING HIS LEVEL 999 POWER!` | `NOBODY COULD STOP HIM!` | Hidden God-Mode Awakening |
| **03** | `03_Sinematik_Malikane_Yuzlesmesi.mp4` | `_Hook_TR.mp4` | **TR** | `SEVİYESİYLE DALGA GEÇTİLER` | `BÜTÜN MALİKANEYİ ALDI!` | Poolside Snob Confrontation Flip |
| **03** | `03_Sinematik_Malikane_Yuzlesmesi.mp4` | `_Hook_EN.mp4` | **EN** | `THEY LAUGHED AT HIS LEVEL...` | `UNTIL HE BOUGHT THE MANSION!` | Billionaire Flex via Game High Score |
| **04** | `04_500_Tuglali_Kasa_Tuzagi_Kurtarma.mp4` | `_Hook_TR.mp4` | **TR** | `KASAYI KİMSE AÇAMADI AMA O...` | `500 TUĞLAYI TEK VURUŞTA KIRDI!` | 500-Brick Vault Trap & Muscle Rescue |
| **04** | `04_500_Tuglali_Kasa_Tuzagi_Kurtarma.mp4` | `_Hook_EN.mp4` | **EN** | `NOBODY BELIEVED HE COULD BEAT LEVEL 500!` | `WATCH THIS INSANE BREAKOUT!` | Impossible Puzzle Rescue Challenge |
| **05** | `05_YuzdeYuz_Meyve_Cekici_Strawberry_Diva_Acilis.mp4` | `_Hook_TR.mp4` | **TR** | `GECE BOYU NEYİ PARÇALIYORDU?!` | `YENİ KRALİÇE TAHTI ELE GEÇİRDİ!` | Diva Ruined vs. New Queen Ascension |
| **05** | `05_YuzdeYuz_Meyve_Cekici_Strawberry_Diva_Acilis.mp4` | `_Hook_EN.mp4` | **EN** | `WHAT WAS SHE SMASHING ALL NIGHT?!` | `FROM RUINED TO TOTAL EMPIRE!` | Midnight Grinding Empire Overhaul |

---

### 4.2 README_VIDEOLAR.md Specification
The documentation file `C:\Users\USER\Desktop\Kirmatas_Reklam_Videolari\README_VIDEOLAR.md` must follow this exact section structure:

1. **Title & Package Overview**:
   - Executive header, total asset count (5 Masters + 10 Hook Variants + Raw Scene Clips), game identity (`Kırmataş` - `com.kaunos.kirmatas`).
2. **Master Video Catalog (Table)**:
   - Index, Filename, Story Title, Duration (s), Size (MB), Resolution (720x1280), FPS, Codecs (H.264 / AAC), Direct CloudFront / Source URL.
3. **Viral Hook Overlay Variants Catalog (Table)**:
   - Index, Variant Filename, Language (TR / EN), Hook Line 1, Hook Line 2, Duration, Resolution, Optimal Platform (TikTok, Reels, Shorts).
4. **Narrative & Storyboard Breakdown**:
   - Deep dive into each of the 5 storylines: Character identities (Strawberry Diva, Watermelon Girl/Juggernaut, Peach Goddess, Pineapple Chad), setting, dramatic conflict, and the psychological conversion hook.
5. **Raw Scene Clips Archive Structure (`Scenes/`)**:
   - Explanation of individual scene splits (Intro, Conflict, Climax, CTA) preserved for post-production video editors.
6. **Social Media & Performance Marketing Guidelines**:
   - Recommended bidding formats, sound-on vs sound-off best practices, optimal captioning, and target CTR benchmarks (target >3.8% CTR on TikTok/Instagram Reels).
7. **Reproduction & Verification Script**:
   - Documented Node.js / FFmpeg command strings used to render the overlays so future variants can be generated automatically.

---

### 4.3 FFmpeg Batch Script Architecture (For Implementer Worker)

```javascript
import { execFileSync } from 'child_process';
import path from 'path';

const FFMPEG = 'C:/Users/USER/AppData/Local/Microsoft/WinGet/Packages/Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe/ffmpeg-9.0.2-full_build/bin/ffmpeg.exe';
const FONT = 'C\\:/Windows/Fonts/arialbd.ttf';
const BASE_DIR = 'C:/Users/USER/Desktop/Kirmatas_Reklam_Videolari';

const VARIANTS = [
  {
    src: '01_Ilk_Drama_Reklami.mp4',
    out: '01_Ilk_Drama_Reklami_Hook_TR.mp4',
    line1: 'HERKES ONU EZİK SANDI',
    line2: 'AMA REKORU KIRDI!'
  },
  {
    src: '01_Ilk_Drama_Reklami.mp4',
    out: '01_Ilk_Drama_Reklami_Hook_EN.mp4',
    line1: 'THEY THOUGHT SHE WAS BROKE...',
    line2: 'UNTIL LEVEL 999 UNLOCKED!'
  },
  // ... and so on for all 10 variants
];

for (const v of VARIANTS) {
  const vf = [
    'drawbox=x=30:y=60:w=660:h=130:color=black@0.85:t=fill',
    'drawbox=x=30:y=60:w=660:h=130:color=yellow@0.9:t=3',
    `drawtext=fontfile='${FONT}':text='${v.line1}':fontcolor=white:fontsize=36:x=(w-text_w)/2:y=78`,
    `drawtext=fontfile='${FONT}':text='${v.line2}':fontcolor=yellow:fontsize=42:x=(w-text_w)/2:y=122`
  ].join(',');

  execFileSync(FFMPEG, [
    '-i', path.join(BASE_DIR, v.src),
    '-vf', vf,
    '-c:v', 'libx264',
    '-preset', 'medium',
    '-crf', '18',
    '-c:a', 'copy',
    path.join(BASE_DIR, v.out),
    '-y'
  ], { stdio: 'inherit' });
}
```

---

## 5. Verification Method

To independently verify these findings and implementations:

1. **Verify Master Files in Target Directory**:
   ```powershell
   Get-ChildItem "C:\Users\USER\Desktop\Kirmatas_Reklam_Videolari\*.mp4" | Select-Object Name, Length
   ```
   *Expected*: All 5 master files exist and are > 1MB.

2. **Verify Video Stream Parameters via FFprobe**:
   ```powershell
   & "C:\Users\USER\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-9.0.2-full_build\bin\ffprobe.exe" -v error -select_streams v:0 -show_entries stream=width,height,codec_name -of csv=p=0 "C:\Users\USER\Desktop\Kirmatas_Reklam_Videolari\01_Ilk_Drama_Reklami.mp4"
   ```
   *Expected*: `h264,720,1280`.

3. **Verify Turkish Character Rendering**:
   ```powershell
   Test-Path "c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\explorer_survey_3\frames\test_tr_node.jpg"
   ```
   *Expected*: `True` (image exists, visual inspection shows crisp Turkish glyphs `GİZLİ 999. SEVİYE GÜCÜNÜ KİMSE BİLMİYORDU!`).

4. **Verify Scenes Directory**:
   ```powershell
   Test-Path "C:\Users\USER\Desktop\Kirmatas_Reklam_Videolari\Scenes"
   ```
   *Current state*: `False` (Must be created and populated by Worker).

5. **Invalidation Conditions**:
   - Any video generated without audio stream.
   - Any hook overlay that renders missing glyph characters (`?` or `□`).
   - Any hook overlay placed below `y=300` causing overlap with bottom captions.
