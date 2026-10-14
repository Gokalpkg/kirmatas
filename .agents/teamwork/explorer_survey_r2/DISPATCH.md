## 2026-10-11T18:14:21Z
You are an Explorer agent investigating requirement R2.
Your working directory is: c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\explorer_survey_r2\
Project root is: c:\Users\USER\Desktop\KIPKIRMATAS

MANDATORY FIRST STEP: Read ORIGINAL_REQUEST.md at:
c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\ORIGINAL_REQUEST.md

Your objective:
Conduct an in-depth code survey of requirement R2:
"Transform Piercing / Fireball Power-Up into Golden-Flame 'Yakıcı Top' (Remove Claude-Style Starburst Icon)"
Investigate:
1. Piercing and Fireball power-up definitions and models:
   - Where PowerUpType.pierce and PowerUpType.fireball are defined (e.g. lib/models/power_up.dart or similar).
   - Localization / display names / banners (e.g. "🔥 YAKICI TOP!", "🔥 SEARING BALL!", etc.).
   - Controller state in lib/engine/game_controller.dart (isFireball, isPierce, durations, brick piercing vs steel brick melting behavior).
2. Canvas rendering in lib/ui/game_canvas.dart:
   - Where isFireball, claudeStar, innerStar, and the 6-pointed starburst polygon are currently drawn.
   - Exact implementation of ball rendering, effects, particle trails, shader/paint usage.
   - The requirement for zero MaskFilter.blur (high-FPS), multi-layered swirling golden-amber and solar-orange organic flame tongues / fire petals curling opposite velocity vector, and molten gold armored core with rotating golden solar ring/crest inside the sphere.
   - How Corner Shot directional jet afterburner is drawn so Yakıcı Top is visually distinct.
3. Capsule and icon rendering:
   - How falling capsules are rendered, PixelArt icons for pierce / fireball, sprite or path drawing.
4. Existing tests in test/ relating to fireball, pierce, power-up effects and rendering.

Write your findings to:
c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\explorer_survey_r2\analysis.md
and a complete handoff report to:
c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\explorer_survey_r2\handoff.md

Report back when done with send_message.
