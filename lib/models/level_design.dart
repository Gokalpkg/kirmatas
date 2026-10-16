import 'dart:math';
import 'package:flutter/material.dart';
import 'brick.dart';

class LevelDesign {
  // --- 38 ÖZEL PİKSEL-ART ŞEKİL MATRİSİ (SHAPES MODE: 38 BÖLÜM) ---
  // 1. Kalp
  static const List<List<int>> shapeHeart = [
    [0, 1, 1, 0, 1, 1, 0],
    [1, 1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1],
    [0, 1, 1, 1, 1, 1, 0],
    [0, 0, 1, 1, 1, 0, 0],
    [0, 0, 0, 1, 0, 0, 0],
  ];

  // 2. Kuru Kafa (Skull)
  static const List<List<int>> shapeSkull = [
    [0, 1, 1, 1, 1, 1, 0],
    [1, 1, 1, 1, 1, 1, 1],
    [1, 0, 1, 1, 1, 0, 1],
    [1, 0, 1, 1, 1, 0, 1],
    [0, 1, 1, 0, 1, 1, 0],
    [0, 0, 1, 1, 1, 0, 0],
    [0, 0, 1, 0, 1, 0, 0],
  ];

  // 3. Kılıç (Sword)
  static const List<List<int>> shapeSword = [
    [0, 0, 0, 1, 0, 0, 0],
    [0, 0, 0, 1, 0, 0, 0],
    [0, 0, 0, 1, 0, 0, 0],
    [0, 1, 1, 1, 1, 1, 0],
    [0, 0, 0, 1, 0, 0, 0],
    [0, 0, 1, 1, 1, 0, 0],
  ];

  // 4. Elmas (Diamond)
  static const List<List<int>> shapeDiamond = [
    [0, 0, 0, 1, 0, 0, 0],
    [0, 0, 1, 1, 1, 0, 0],
    [0, 1, 1, 1, 1, 1, 0],
    [1, 1, 1, 1, 1, 1, 1],
    [0, 1, 1, 1, 1, 1, 0],
    [0, 0, 1, 1, 1, 0, 0],
    [0, 0, 0, 1, 0, 0, 0],
  ];

  // 5. Gülen Yüz (Smiley)
  static const List<List<int>> shapeSmiley = [
    [0, 1, 1, 1, 1, 1, 0],
    [1, 0, 1, 0, 1, 0, 1],
    [1, 0, 0, 0, 0, 0, 1],
    [1, 0, 1, 0, 1, 0, 1],
    [1, 0, 0, 1, 0, 0, 1],
    [0, 1, 1, 0, 1, 1, 0],
  ];

  // 6. Yıldız (Star)
  static const List<List<int>> shapeStar = [
    [0, 0, 0, 1, 0, 0, 0],
    [0, 0, 1, 1, 1, 0, 0],
    [1, 1, 1, 1, 1, 1, 1],
    [0, 1, 1, 1, 1, 1, 0],
    [0, 0, 1, 1, 1, 0, 0],
    [0, 1, 1, 0, 1, 1, 0],
    [1, 1, 0, 0, 0, 1, 1],
  ];

  // 7. Roket (Rocket)
  static const List<List<int>> shapeRocket = [
    [0, 0, 0, 1, 0, 0, 0],
    [0, 0, 1, 1, 1, 0, 0],
    [0, 0, 1, 0, 1, 0, 0],
    [0, 1, 1, 1, 1, 1, 0],
    [1, 0, 1, 1, 1, 0, 1],
    [1, 0, 1, 1, 1, 0, 1],
    [0, 0, 0, 1, 0, 0, 0],
  ];

  // 8. Taç (Crown)
  static const List<List<int>> shapeCrown = [
    [1, 0, 0, 1, 0, 0, 1],
    [1, 1, 0, 1, 0, 1, 1],
    [1, 1, 1, 1, 1, 1, 1],
    [1, 0, 1, 1, 1, 0, 1],
    [1, 1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1],
  ];

  // 9. Hayalet (Ghost)
  static const List<List<int>> shapeGhost = [
    [0, 1, 1, 1, 1, 1, 0],
    [1, 1, 1, 1, 1, 1, 1],
    [1, 0, 1, 1, 0, 1, 1],
    [1, 0, 1, 1, 0, 1, 1],
    [1, 1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1],
    [1, 0, 1, 0, 1, 0, 1],
  ];

  // 10. Mantar (Mushroom)
  static const List<List<int>> shapeMushroom = [
    [0, 0, 1, 1, 1, 0, 0],
    [0, 1, 1, 1, 1, 1, 0],
    [1, 0, 1, 1, 1, 0, 1],
    [1, 1, 1, 1, 1, 1, 1],
    [0, 0, 1, 1, 1, 0, 0],
    [0, 0, 1, 1, 1, 0, 0],
  ];

  // 11. Gamepad (Retro Controller)
  static const List<List<int>> shapeGamepad = [
    [0, 1, 1, 1, 1, 1, 0],
    [1, 1, 1, 1, 1, 1, 1],
    [1, 0, 1, 0, 1, 0, 1],
    [1, 1, 1, 1, 1, 1, 1],
    [1, 0, 0, 0, 0, 0, 1],
    [1, 0, 0, 0, 0, 0, 1],
  ];

  // 12. Şimşek (Lightning)
  static const List<List<int>> shapeLightning = [
    [0, 0, 0, 1, 1, 0, 0],
    [0, 0, 1, 1, 0, 0, 0],
    [0, 1, 1, 1, 1, 1, 0],
    [0, 0, 0, 1, 1, 0, 0],
    [0, 0, 1, 1, 0, 0, 0],
    [0, 1, 1, 0, 0, 0, 0],
    [1, 0, 0, 0, 0, 0, 0],
  ];

  // 13. Balık (Fish)
  static const List<List<int>> shapeFish = [
    [0, 0, 1, 0, 0, 0, 0],
    [0, 1, 1, 1, 0, 0, 1],
    [1, 0, 1, 1, 1, 1, 1],
    [0, 1, 1, 1, 0, 0, 1],
    [0, 0, 1, 0, 0, 0, 0],
  ];

  // 14. Çapa (Anchor)
  static const List<List<int>> shapeAnchor = [
    [0, 0, 1, 1, 1, 0, 0],
    [0, 0, 1, 0, 1, 0, 0],
    [0, 1, 1, 1, 1, 1, 0],
    [0, 0, 0, 1, 0, 0, 0],
    [1, 0, 0, 1, 0, 0, 1],
    [1, 1, 1, 1, 1, 1, 1],
    [0, 1, 1, 0, 1, 1, 0],
  ];

  // 15. Kalkan (Shield)
  static const List<List<int>> shapeShield = [
    [1, 1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1],
    [1, 0, 1, 1, 1, 0, 1],
    [0, 1, 1, 1, 1, 1, 0],
    [0, 0, 1, 1, 1, 0, 0],
    [0, 0, 0, 1, 0, 0, 0],
  ];

  // 16. Kupa (Trophy)
  static const List<List<int>> shapeTrophy = [
    [1, 1, 1, 1, 1, 1, 1],
    [1, 0, 1, 1, 1, 0, 1],
    [1, 0, 1, 1, 1, 0, 1],
    [0, 1, 1, 1, 1, 1, 0],
    [0, 0, 0, 1, 0, 0, 0],
    [0, 0, 1, 1, 1, 0, 0],
    [0, 1, 1, 1, 1, 1, 0],
  ];

  // 17. Anahtar (Key)
  static const List<List<int>> shapeKey = [
    [0, 0, 1, 1, 1, 0, 0],
    [0, 1, 0, 0, 0, 1, 0],
    [0, 0, 1, 1, 1, 0, 0],
    [0, 0, 0, 1, 0, 0, 0],
    [0, 0, 0, 1, 1, 1, 0],
    [0, 0, 0, 1, 0, 0, 0],
    [0, 0, 0, 1, 1, 1, 0],
  ];

  // 18. Ağaç (Tree)
  static const List<List<int>> shapeTree = [
    [0, 0, 0, 1, 0, 0, 0],
    [0, 0, 1, 1, 1, 0, 0],
    [0, 1, 1, 1, 1, 1, 0],
    [0, 0, 1, 1, 1, 0, 0],
    [0, 1, 1, 1, 1, 1, 0],
    [1, 1, 1, 1, 1, 1, 1],
    [0, 0, 0, 1, 0, 0, 0],
  ];

  // 19. Çan (Bell)
  static const List<List<int>> shapeBell = [
    [0, 0, 0, 1, 0, 0, 0],
    [0, 0, 1, 1, 1, 0, 0],
    [0, 1, 1, 1, 1, 1, 0],
    [0, 1, 1, 1, 1, 1, 0],
    [1, 1, 1, 1, 1, 1, 1],
    [0, 0, 1, 1, 1, 0, 0],
  ];

  // 20. Sandık (Treasure Chest)
  static const List<List<int>> shapeChest = [
    [0, 1, 1, 1, 1, 1, 0],
    [1, 1, 1, 1, 1, 1, 1],
    [1, 0, 1, 1, 1, 0, 1],
    [1, 1, 1, 0, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1],
  ];

  // 21. Uzay Gemisi / Invader
  static const List<List<int>> shapeInvader = [
    [0, 0, 1, 0, 1, 0, 0],
    [0, 0, 0, 1, 0, 0, 0],
    [0, 1, 1, 1, 1, 1, 0],
    [1, 1, 0, 1, 0, 1, 1],
    [1, 1, 1, 1, 1, 1, 1],
    [1, 0, 1, 1, 1, 0, 1],
    [1, 0, 1, 0, 1, 0, 1],
  ];

  // 22. Kiraz (Cherries)
  static const List<List<int>> shapeCherries = [
    [0, 0, 0, 1, 1, 0, 0],
    [0, 0, 1, 0, 0, 1, 0],
    [0, 1, 0, 0, 0, 0, 1],
    [1, 1, 1, 0, 1, 1, 1],
    [1, 1, 1, 0, 1, 1, 1],
    [0, 1, 0, 0, 0, 1, 0],
  ];

  // 23. Alev (Flame)
  static const List<List<int>> shapeFlame = [
    [0, 0, 0, 1, 0, 0, 0],
    [0, 0, 1, 1, 0, 1, 0],
    [0, 1, 1, 1, 1, 1, 0],
    [1, 1, 0, 1, 0, 1, 1],
    [1, 1, 1, 1, 1, 1, 1],
    [0, 1, 1, 1, 1, 1, 0],
    [0, 0, 1, 1, 1, 0, 0],
  ];

  // 24. Kar Tanesi (Snowflake)
  static const List<List<int>> shapeSnowflake = [
    [1, 0, 0, 1, 0, 0, 1],
    [0, 1, 0, 1, 0, 1, 0],
    [0, 0, 1, 1, 1, 0, 0],
    [1, 1, 1, 1, 1, 1, 1],
    [0, 0, 1, 1, 1, 0, 0],
    [0, 1, 0, 1, 0, 1, 0],
    [1, 0, 0, 1, 0, 0, 1],
  ];

  // 25. Güneş (Sun)
  static const List<List<int>> shapeSun = [
    [0, 0, 0, 1, 0, 0, 0],
    [1, 0, 1, 1, 1, 0, 1],
    [0, 1, 1, 1, 1, 1, 0],
    [1, 1, 1, 1, 1, 1, 1],
    [0, 1, 1, 1, 1, 1, 0],
    [1, 0, 1, 1, 1, 0, 1],
    [0, 0, 0, 1, 0, 0, 0],
  ];

  // 26. Hilal / Ay (Moon)
  static const List<List<int>> shapeMoon = [
    [0, 0, 1, 1, 1, 0, 0],
    [0, 1, 1, 0, 0, 0, 0],
    [1, 1, 0, 0, 0, 0, 0],
    [1, 1, 0, 0, 0, 0, 0],
    [1, 1, 0, 0, 0, 0, 0],
    [0, 1, 1, 0, 0, 0, 0],
    [0, 0, 1, 1, 1, 0, 0],
  ];

  // 27. Elma (Apple)
  static const List<List<int>> shapeApple = [
    [0, 0, 0, 1, 1, 0, 0],
    [0, 0, 0, 1, 0, 0, 0],
    [0, 1, 1, 0, 1, 1, 0],
    [1, 1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1],
    [0, 1, 1, 0, 1, 1, 0],
  ];

  // 28. Kanca (Hook)
  static const List<List<int>> shapeHook = [
    [0, 0, 1, 1, 1, 0, 0],
    [0, 1, 0, 0, 0, 1, 0],
    [0, 0, 0, 0, 0, 1, 0],
    [0, 0, 0, 0, 1, 0, 0],
    [0, 0, 0, 1, 0, 0, 0],
    [0, 0, 1, 1, 1, 0, 0],
    [0, 1, 1, 1, 1, 1, 0],
  ];

  // 29. Zümrüt Kristal (Gem)
  static const List<List<int>> shapeGem = [
    [0, 1, 1, 1, 1, 1, 0],
    [1, 1, 0, 1, 0, 1, 1],
    [1, 1, 1, 1, 1, 1, 1],
    [0, 1, 1, 1, 1, 1, 0],
    [0, 0, 1, 1, 1, 0, 0],
    [0, 0, 0, 1, 0, 0, 0],
  ];

  // 30. Bomba (Bomb)
  static const List<List<int>> shapeBomb = [
    [0, 0, 0, 0, 1, 0, 1],
    [0, 0, 0, 1, 0, 0, 0],
    [0, 0, 1, 1, 1, 0, 0],
    [0, 1, 1, 1, 1, 1, 0],
    [1, 0, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1],
    [0, 1, 1, 1, 1, 1, 0],
  ];

  // 31. Müzik Notası (Music Note)
  static const List<List<int>> shapeNote = [
    [0, 0, 1, 1, 1, 1, 0],
    [0, 0, 1, 0, 0, 1, 0],
    [0, 0, 1, 0, 0, 1, 0],
    [0, 0, 1, 0, 0, 1, 0],
    [0, 1, 1, 0, 1, 1, 0],
    [1, 1, 1, 1, 1, 1, 0],
  ];

  // 32. Bayrak (Flag)
  static const List<List<int>> shapeFlag = [
    [1, 1, 1, 1, 1, 0, 0],
    [1, 1, 1, 1, 0, 0, 0],
    [1, 1, 1, 1, 1, 0, 0],
    [1, 0, 0, 0, 0, 0, 0],
    [1, 0, 0, 0, 0, 0, 0],
    [1, 0, 0, 0, 0, 0, 0],
    [1, 1, 1, 0, 0, 0, 0],
  ];

  // 33. Kum Saati (Hourglass)
  static const List<List<int>> shapeHourglass = [
    [1, 1, 1, 1, 1, 1, 1],
    [0, 1, 1, 1, 1, 1, 0],
    [0, 0, 1, 1, 1, 0, 0],
    [0, 0, 0, 1, 0, 0, 0],
    [0, 0, 1, 1, 1, 0, 0],
    [0, 1, 1, 1, 1, 1, 0],
    [1, 1, 1, 1, 1, 1, 1],
  ];

  // 34. Büyüteç (Magnifier)
  static const List<List<int>> shapeMagnifier = [
    [0, 1, 1, 1, 1, 0, 0],
    [1, 1, 0, 0, 1, 1, 0],
    [1, 0, 0, 0, 0, 1, 0],
    [1, 1, 0, 0, 1, 1, 0],
    [0, 1, 1, 1, 1, 0, 0],
    [0, 0, 0, 0, 0, 1, 0],
    [0, 0, 0, 0, 0, 0, 1],
  ];

  // 35. Yüzük (Ring)
  static const List<List<int>> shapeRing = [
    [0, 0, 0, 1, 0, 0, 0],
    [0, 0, 1, 1, 1, 0, 0],
    [0, 1, 1, 0, 1, 1, 0],
    [1, 1, 0, 0, 0, 1, 1],
    [1, 1, 0, 0, 0, 1, 1],
    [0, 1, 1, 1, 1, 1, 0],
  ];

  // 36. Kilitli Kalp (Heart Lock)
  static const List<List<int>> shapeHeartLock = [
    [0, 0, 1, 1, 1, 0, 0],
    [0, 0, 1, 0, 1, 0, 0],
    [0, 1, 1, 0, 1, 1, 0],
    [1, 1, 1, 1, 1, 1, 1],
    [1, 1, 0, 1, 0, 1, 1],
    [0, 1, 1, 1, 1, 1, 0],
    [0, 0, 0, 1, 0, 0, 0],
  ];

  // 37. Sonsuzluk (Infinity)
  static const List<List<int>> shapeInfinity = [
    [0, 1, 1, 0, 1, 1, 0],
    [1, 0, 0, 1, 0, 0, 1],
    [1, 0, 0, 1, 0, 0, 1],
    [0, 1, 1, 0, 1, 1, 0],
  ];

  // 38. Ejderha / Phoenix
  static const List<List<int>> shapeDragon = [
    [1, 0, 0, 1, 0, 0, 1],
    [1, 1, 0, 1, 0, 1, 1],
    [1, 1, 1, 1, 1, 1, 1],
    [0, 1, 1, 1, 1, 1, 0],
    [0, 0, 1, 1, 1, 0, 0],
    [0, 1, 0, 1, 0, 1, 0],
    [1, 0, 0, 0, 0, 0, 1],
  ];

  static const List<List<List<int>>> allShapes = [
    shapeHeart,      // 1
    shapeSkull,      // 2
    shapeSword,      // 3
    shapeDiamond,    // 4
    shapeSmiley,     // 5
    shapeStar,       // 6
    shapeRocket,     // 7
    shapeCrown,      // 8
    shapeGhost,      // 9
    shapeMushroom,   // 10
    shapeGamepad,    // 11
    shapeLightning,  // 12
    shapeFish,       // 13
    shapeAnchor,     // 14
    shapeShield,     // 15
    shapeTrophy,     // 16
    shapeKey,        // 17
    shapeTree,       // 18
    shapeBell,       // 19
    shapeChest,      // 20
    shapeInvader,    // 21
    shapeCherries,   // 22
    shapeFlame,      // 23
    shapeSnowflake,  // 24
    shapeSun,        // 25
    shapeMoon,       // 26
    shapeApple,      // 27
    shapeHook,       // 28
    shapeGem,        // 29
    shapeBomb,       // 30
    shapeNote,       // 31
    shapeFlag,       // 32
    shapeHourglass,  // 33
    shapeMagnifier,  // 34
    shapeRing,       // 35
    shapeHeartLock,  // 36
    shapeInfinity,   // 37
    shapeDragon,     // 38
  ];

  static const List<Color> magmaPalette = [
    Color(0xFFFF3D00),
    Color(0xFFFF6D00),
    Color(0xFFFF9100),
    Color(0xFFD84315),
    Color(0xFFBF360C),
    Color(0xFFFF5722),
  ];

  static const List<Color> icePalette = [
    Color(0xFFE1F5FE),
    Color(0xFF81D4FA),
    Color(0xFF4FC3F7),
    Color(0xFF29B6F6),
    Color(0xFFB3E5FC),
    Color(0xFF80DEEA),
  ];

  static const List<Color> candyPalette = [
    Color(0xFFFF4081),
    Color(0xFFE040FB),
    Color(0xFF7C4DFF),
    Color(0xFFFF80AB),
    Color(0xFFEA80FC),
    Color(0xFFB388FF),
  ];

  static const List<Color> tuftPalette = [
    Color(0xFFFF7043),
    Color(0xFFFFD54F),
    Color(0xFF4DD0E1),
    Color(0xFF81C784),
    Color(0xFFBA68C8),
    Color(0xFFFF8A80),
    Color(0xFF4FC3F7),
    Color(0xFFAED581),
  ];

  static const List<Color> neonPalette = [
    Color(0xFF00E5FF),
    Color(0xFFFF007F),
    Color(0xFFFFD600),
    Color(0xFF00E676),
    Color(0xFF7C4DFF),
    Color(0xFFFF6D00),
  ];

  static const List<Color> goldPalette = [
    Color(0xFFFFD54F),
    Color(0xFFFFC107),
    Color(0xFFFFB300),
    Color(0xFFFFA000),
    Color(0xFFFF8F00),
    Color(0xFFFFE082),
  ];

  static const List<Color> naturePalette = [
    Color(0xFF81C784),
    Color(0xFF4CAF50),
    Color(0xFF388E3C),
    Color(0xFF2E7D32),
    Color(0xFFA5D6A7),
    Color(0xFF66BB6A),
  ];

  static const double baseTopMargin = 105.0;

  static int getWorldIndex(int level) {
    if (level <= 35) return 1;
    if (level <= 75) return 2;
    if (level <= 115) return 3;
    if (level <= 155) return 4;
    if (level <= 195) return 5;
    return 6;
  }

  static int decadeIndex(int level) => (level - 1) ~/ 10;

  /// One brick rule for each 10-level band, starting at level 11.
  static String? decadeRuleKey(int level) {
    if (level < 11) return null;
    switch (decadeIndex(level) % 4) {
      case 1:
        return 'rule_ice';
      case 2:
        return 'rule_steel';
      case 3:
        return 'rule_mover';
      default:
        return 'rule_dynamite';
    }
  }

  static void _applyDecadeSignature(List<Brick> bricks, int level) {
    if (level < 11 || isBossLevelNumber(level)) return;
    final key = decadeRuleKey(level);
    if (key == null) return;
    final present = switch (key) {
      'rule_ice' => bricks.any((b) => b.isIce),
      'rule_steel' => bricks.any((b) => b.isSteel || b.isHeavySteel),
      'rule_mover' => bricks.any((b) => b.isMover),
      'rule_dynamite' => bricks.any((b) => b.isDynamite),
      _ => true,
    };
    if (present) return;
    Brick? pick;
    for (final b in bricks) {
      if (b.isBoss || b.isSteel || b.isHeavySteel || b.isIce || b.isDynamite || b.isMover) continue;
      pick = b;
      break;
    }
    if (pick == null) return;
    switch (key) {
      case 'rule_ice':
        pick.isIce = true;
        break;
      case 'rule_steel':
        final breakable = bricks.where((b) => !b.isSteel && !b.isHeavySteel).length;
        if (breakable <= 6) return;
        pick.isSteel = true;
        pick.hp = 999;
        pick.maxHp = 999;
        pick.points = 0;
        pick.color = const Color(0xFF78909C);
        break;
      case 'rule_mover':
        pick.isMover = true;
        break;
      case 'rule_dynamite':
        pick.isDynamite = true;
        pick.hp = 1;
        pick.maxHp = 1;
        break;
    }
  }

  static String getWorldName(int level) {
    switch (getWorldIndex(level)) {
      case 1:
        return 'Neon Başlangıç';
      case 2:
        return 'Siber Bastion';
      case 3:
        return 'Manyetik Girdap';
      case 4:
        return 'Kristal Labirent';
      case 5:
        return 'Lav Çölü & Titanyum';
      case 6:
      default:
        return 'Kuantum Zirvesi';
    }
  }

  static List<Color> getWorldPalette(int worldIndex) {
    switch (worldIndex) {
      case 1:
        return const [
          Color(0xFF00E5FF), // Cyber Cyan
          Color(0xFFFF007F), // Electric Magenta
          Color(0xFFFFD600), // Bright Yellow
          Color(0xFF00E676), // Neon Green
          Color(0xFF7C4DFF), // Vivid Purple
          Color(0xFFFF6D00), // Neon Orange
        ];
      case 2:
        return const [
          Color(0xFF2979FF), // Cobalt Blue
          Color(0xFFFF5252), // Bright Coral
          Color(0xFFFFB300), // Amber Gold
          Color(0xFF1DE9B6), // Mint
          Color(0xFF3D5AFE), // Deep Indigo
          Color(0xFFFF1744), // Crimson
        ];
      case 3:
        return const [
          Color(0xFF651FFF), // Electric Violet
          Color(0xFFFF1744), // Neon Magenta
          Color(0xFF00E5FF), // Pulsar Cyan
          Color(0xFF304FFE), // Twilight Indigo
          Color(0xFFFFEA00), // Electric Yellow
          Color(0xFFE040FB), // Plasma Purple
        ];
      case 4:
        return const [
          Color(0xFF00E676), // Emerald
          Color(0xFF00B0FF), // Deep Azure
          Color(0xFFAA00FF), // Radiant Amethyst
          Color(0xFFFFC400), // Gold Amber
          Color(0xFFFF4081), // Rose Quartz
          Color(0xFF18FFFF), // Electric Diamond
        ];
      case 5:
        return const [
          Color(0xFFFF3D00), // Molten Orange
          Color(0xFFD50000), // Lava Crimson
          Color(0xFFFFAB00), // Fiery Gold
          Color(0xFFDD2C00), // Burning Ochre
          Color(0xFFFF6D00), // Solar Flare
          Color(0xFFFF1744), // Magma Red
        ];
      case 6:
      default:
        return const [
          Color(0xFF2979FF), // Quantum Sapphire
          Color(0xFF7C4DFF), // Astral Purple
          Color(0xFFFFD700), // Solar Gold
          Color(0xFFFF1493), // Plasma Pink
          Color(0xFF00F5FF), // Pure Cyan
          Color(0xFFFF6E40), // Singularity Coral
        ];
    }
  }

  static int _selectArchetype(int level, int world, int step) {
    if (level == 238) return 29; // OmegaFinal Apex
    final cycleIndex = level ~/ 10;
    switch (step) {
      case 1:
        return (cycleIndex % 2 == 0) ? 0 : 1; // Checkerboard or DominoChain
      case 2:
        return [2, 3, 4, 12][cycleIndex % 4]; // DiamondMine, SpiralGalaxy, IceAvalanche, StarOfDestiny
      case 3:
        return [5, 6, 7][cycleIndex % 3]; // CastleFortress, Honeycomb, PillarsOfHercules
      case 4:
        return [8, 9, 10, 11][cycleIndex % 4]; // SymmetricTotem, AlienInvader, DoubleHelix, Arrowhead
      case 6:
        return [13, 14, 15][cycleIndex % 3]; // PrecisionSlit, IronCurtain, DualConvoys
      case 7:
        return [16, 17, 18, 19][cycleIndex % 4]; // BunkerVault, ZigzagMaze, TheGauntlet, TheFunnel
      case 8:
        return [20, 21, 22, 23][cycleIndex % 4]; // TargetBullseye, TwinTowers, SkullFortress, ShieldAndCrown
      case 9:
        return [24, 25, 26, 27, 28][cycleIndex % 5]; // SwordOfJustice, Hourglass, HeartOfStone, QuantumMatrix, Eclipse
      default:
        return 0;
    }
  }

  static bool _getArchetypeCell(int archetype, int r, int c, int rows, int cols, int level) {
    switch (archetype) {
      case 0: // Checkerboard
        return (r + c) % 2 == 0;
      case 1: // DominoChain — both side edges stay in the chain
        final fromEdge = min(c, cols - 1 - c);
        if (r % 2 == 0) return fromEdge % 2 == 0;
        return fromEdge % 2 == 1 && c != 0 && c != cols - 1;
      case 2: // DiamondMine — centered so both side edges and both tips exist
        final midR = (rows - 1) / 2.0;
        final midC = (cols - 1) / 2.0;
        final dr = (r - midR).abs() / max(midR, 0.5);
        final dc = (c - midC).abs() / max(midC, 0.5);
        return (dr + dc) <= 1.22;
      case 3: // SpiralGalaxy
        return (r == 0 && c < cols - 1) ||
            (c == cols - 1 && r < rows - 1) ||
            (r == rows - 1 && c > 0) ||
            (c == 0 && r > 1) ||
            (r >= 2 && r <= rows - 3 && c >= 2 && c <= cols - 3 && ((r + c) % 2 == 0));
      case 4: // IceAvalanche — peak on the top edge, full base on both sides
        final midC = (cols - 1) / 2.0;
        final dist = (c - midC).abs();
        final inner = dist <= 0.51 ? 0.0 : dist - 0.51;
        final half = max(midC - 0.51, 0.5);
        final t = (inner / half).clamp(0.0, 1.0);
        return r >= (t * (rows - 1)).floor();
      case 5: // CastleFortress
        return c == 0 ||
            c == cols - 1 ||
            (r == 0 && min(c, cols - 1 - c) % 2 == 0) ||
            (r >= rows - 2) ||
            (r >= 2 && (c == 2 || c == cols - 3));
      case 6: // Honeycomb
        return r % 2 == 0 ? (c % 2 == 0) : (c % 2 == 1);
      case 7: // PillarsOfHercules — both side columns stay solid
        if (c == 0 || c == cols - 1 || r == 0 || r == rows - 1) return true;
        return min(c, cols - 1 - c) % 3 != 1;
      case 8: // SymmetricTotem
        final dc = (c - (cols - 1) / 2.0).abs();
        final dr = (r - (rows - 1) / 2.0).abs();
        return (dc + dr <= (rows + cols) * 0.38) && !(r % 2 == 1 && dc < 0.6);
      case 9: // AlienInvader
        final cNorm = (c < cols / 2) ? c : (cols - 1 - c);
        return (r == 0 && cNorm == 1) ||
            (r == 1 && (cNorm == 0 || cNorm == 2)) ||
            (r == 2 && cNorm >= 0) ||
            (r == 3 && cNorm != 1) ||
            (r >= 4 && (cNorm == 0 || cNorm == cols ~/ 2));
      case 10: // DoubleHelix
        final h1 = ((r * 1.3).round()) % cols;
        final h2 = cols - 1 - (((r * 1.3).round()) % cols);
        return c == h1 || c == h2 || (r % 3 == 0 && c >= min(h1, h2) && c <= max(h1, h2));
      case 11: // Arrowhead — wide top edge, tip centered on the bottom edge
        final midC = (cols - 1) / 2.0;
        final dist = (c - midC).abs();
        final inner = dist <= 0.51 ? 0.0 : dist - 0.51;
        final half = max(midC - 0.51, 0.5);
        final t = (inner / half).clamp(0.0, 1.0);
        return r <= ((1.0 - t) * (rows - 1)).floor();
      case 12: // StarOfDestiny
        final midR = (rows - 1) / 2.0;
        final midC = (cols - 1) / 2.0;
        final onCross = (r - midR).abs() <= 0.51 || (c - midC).abs() <= 0.51;
        final nr = rows <= 1 ? 0.0 : r / (rows - 1);
        final nc = cols <= 1 ? 0.0 : c / (cols - 1);
        final tol = 0.55 / max(rows - 1, cols - 1);
        final onDiag = (nr - nc).abs() <= tol || (nr + nc - 1).abs() <= tol;
        return onCross || onDiag;
      case 13: // PrecisionSlit
        final slitCol = cols ~/ 2;
        return !(r == rows - 2 && c == slitCol);
      case 14: // IronCurtain
        return r % 2 == 0 || (c != (r * 2) % cols && c != (r * 2 + 1) % cols);
      case 15: // DualConvoys
        return r % 2 == 0 || (c > 0 && c < cols - 1);
      case 16: // BunkerVault
        return r == 0 || r == rows - 1 || c == 0 || c == cols - 1 || (r == rows ~/ 2 && c == cols ~/ 2);
      case 17: // ZigzagMaze
        return r % 2 == 0 || (r % 4 == 1 && c == cols - 1) || (r % 4 == 3 && c == 0);
      case 18: // TheGauntlet
        return c <= 1 || c >= cols - 2 || (r % 2 == 0 && c == cols ~/ 2);
      case 19: // TheFunnel — top edge closed, both side columns run to the bottom
        final midC = (cols - 1) / 2.0;
        final dist = (c - midC).abs();
        final inner = dist <= 0.51 ? 0.0 : dist - 0.51;
        final half = max(midC - 0.51, 0.5);
        final t = (inner / half).clamp(0.0, 1.0);
        return r <= (t * (rows - 1)).floor();
      case 20: // TargetBullseye
        final midR = (rows - 1) / 2.0;
        final midC = (cols - 1) / 2.0;
        final dr = (r - midR) / max(midR, 0.5);
        final dc = (c - midC) / max(midC, 0.5);
        final dist = sqrt(dr * dr + dc * dc);
        return dist < 0.42 || (dist > 0.62 && dist <= 1.05);
      case 21: // TwinTowers
        return c <= 1 || c >= cols - 2 || (r == 0 && (c == cols ~/ 2 || c == cols ~/ 2 - 1));
      case 22: // SkullFortress
        if (r < rows - 2) {
          final isEye = (r == rows ~/ 3) && (c == cols ~/ 3 || c == cols - 1 - cols ~/ 3);
          return !isEye;
        } else {
          return c >= 1 && c <= cols - 2 && min(c, cols - 1 - c) % 2 == 0;
        }
      case 23: // ShieldAndCrown — point sits on the bottom edge
        final crownL = (cols - 1) ~/ 2;
        final crownR = cols ~/ 2;
        if (r <= 1) {
          return c == 0 || c == cols - 1 || c == crownL || c == crownR;
        }
        final span = max(1, rows - 2);
        final t = (r - 1) / span;
        final midC = (cols - 1) / 2.0;
        final reach = midC * (1.0 - t);
        return (c - midC).abs() <= reach + 0.55;
      case 24: // SwordOfJustice
        final bladeL = (cols - 1) ~/ 2;
        final bladeR = cols ~/ 2;
        final onBlade = c == bladeL || c == bladeR;
        if (r < rows - 2) {
          return onBlade || (r == 0 && (c == bladeL - 1 || c == bladeR + 1));
        }
        if (r == rows - 2) return true;
        return onBlade;
      case 25: // Hourglass
        final midR = (rows - 1) / 2.0;
        final midC = (cols - 1) / 2.0;
        final waist = 1.0 - (r - midR).abs() / max(midR, 0.5);
        return (c - midC).abs() >= (waist * (cols / 3.0));
      case 26: // HeartOfStone
        final midC = (cols - 1) / 2.0;
        if (r == 0) {
          final lobe = (c - midC).abs();
          final outer = midC * 0.78;
          final inner = max(0.8, midC * 0.22);
          return lobe >= inner && lobe <= outer + 0.05;
        }
        if (r == 1) return true;
        final t = (r - 1) / max(1, rows - 2);
        return (c - midC).abs() <= midC * (1.0 - t) + 0.55;
      case 27: // QuantumMatrix — both side edges stay filled
        if (c == 0 || c == cols - 1 || r % 2 == 0) return true;
        return min(c, cols - 1 - c) % 2 == 0;
      case 28: // Eclipse — full rim, the bite is a smooth inner crescent
        final midR = (rows - 1) / 2.0;
        final midC = (cols - 1) / 2.0;
        final dr = (r - midR) / max(midR, 0.5);
        final dc = (c - midC) / max(midC, 0.5);
        final dist = sqrt(dr * dr + dc * dc);
        if (dist > 1.02) return false;
        final moonDr = dr + 0.05;
        final moonDc = dc - 0.55;
        final moon = sqrt(moonDr * moonDr + moonDc * moonDc);
        return moon >= 0.55 || dist >= 0.82;
      case 29: // OmegaFinal
        final midR = (rows - 1) / 2.0;
        final midC = (cols - 1) / 2.0;
        final dr = (r - midR) / max(midR, 0.5);
        final dc = (c - midC) / max(midC, 0.5);
        final dist = sqrt(dr * dr + dc * dc);
        if (r < rows - 1) return dist >= 0.55 && dist <= 1.12 && (dr < 0.6 || dc.abs() > 0.35);
        return c <= 1 || c >= cols - 2;
      default:
        return true;
    }
  }

  static bool isBossLevelNumber(int level) {
    if (level <= 0) return false;
    // Bosslar 10-15 bölümde bir gelir: 12, 25, 37, 50, 62, 75, 87, 100, 112, 125, 137, 150, 162, 175, 187, 200, 212, 225, 237...
    const bossSequence = [
      12, 25, 37, 50, 62, 75, 87, 100, 112, 125, 137, 150, 162, 175, 187, 200, 212, 225, 237
    ];
    return bossSequence.contains(level);
  }

  static List<Brick> buildClassicLevel(int level, double screenWidth, double screenHeight) {
    final List<Brick> bricks = [];
    final bool isBossLevel = isBossLevelNumber(level);
    final world = getWorldIndex(level);
    const padding = 16.0;

    if (isBossLevel) {
      final isMajorBoss = (level % 25 == 0 || level == 100 || level == 200);
      final bossW = screenWidth * (isMajorBoss ? 0.54 : 0.48);
      final bossH = isMajorBoss ? 40.0 : 36.0;
      final bossX = (screenWidth - bossW) / 2;
      final bossHp = isMajorBoss ? (25 + (level * 3.2).round()) : (20 + (level * 2.5).round());

      // Boss Brick
      bricks.add(
        Brick(
          x: bossX,
          y: baseTopMargin + 10,
          width: bossW,
          height: bossH,
          hp: bossHp,
          maxHp: bossHp,
          isBoss: true,
          bossVx: 75.0 + level * 1.8,
          minX: padding,
          maxX: screenWidth - padding,
          color: isMajorBoss ? const Color(0xFFD50000) : const Color(0xFFFF1744),
          points: isMajorBoss ? 1000 : 500,
        ),
      );

      // Front guard row
      final guardCols = isMajorBoss ? 7 : 6;
      const gap = 6.0;
      final bw = (screenWidth - (padding * 2) - gap * (guardCols - 1)) / guardCols;
      final totalW = guardCols * bw + gap * (guardCols - 1);
      final startX = (screenWidth - totalW) / 2;
      final guardHp = 2 + (world ~/ 2);

      for (int c = 0; c < guardCols; c++) {
        bricks.add(
          Brick(
            x: startX + c * (bw + gap),
            y: baseTopMargin + bossH + 26.0,
            width: bw,
            height: 20.0,
            hp: guardHp,
            maxHp: guardHp,
            color: isMajorBoss ? const Color(0xFFFF6D00) : const Color(0xFFFF9100),
            points: 25 * guardHp,
          ),
        );
      }

      // In World 2+ (level >= 35): Add moving satellite shield interceptors
      if (world >= 2) {
        if (isMajorBoss) {
          // 2 Moving satellite shields sliding in opposite directions
          const satW = 48.0;
          const satH = 18.0;
          bricks.add(
            Brick(
              x: padding,
              y: baseTopMargin + bossH + 52.0,
              width: satW,
              height: satH,
              hp: 3 + world,
              maxHp: 3 + world,
              isMover: true,
              moverVx: 85.0 + level * 0.4,
              minX: padding,
              maxX: screenWidth - padding,
              color: const Color(0xFF00E5FF),
              points: 75,
            ),
          );
          bricks.add(
            Brick(
              x: screenWidth - padding - satW,
              y: baseTopMargin + bossH + 52.0,
              width: satW,
              height: satH,
              hp: 3 + world,
              maxHp: 3 + world,
              isMover: true,
              moverVx: -(85.0 + level * 0.4),
              minX: padding,
              maxX: screenWidth - padding,
              color: const Color(0xFFFF007F),
              points: 75,
            ),
          );
        } else if (level >= 35) {
          // 1 Moving satellite shield for mid-bosses in later worlds
          const satW = 54.0;
          const satH = 18.0;
          bricks.add(
            Brick(
              x: (screenWidth - satW) / 2,
              y: baseTopMargin + bossH + 52.0,
              width: satW,
              height: satH,
              hp: 2 + world,
              maxHp: 2 + world,
              isMover: true,
              moverVx: 80.0 + level * 0.3,
              minX: padding,
              maxX: screenWidth - padding,
              color: const Color(0xFFFFD600),
              points: 50,
            ),
          );
        }
      }

      return bricks;
    }

    // Kishōtenketsu Procedural Progression (Worlds 1 - 6, Levels 1 - 238)
    int rows;
    int cols;
    switch (world) {
      case 1:
        rows = min(7, 5 + (level ~/ 12));
        cols = 6 + (level % 2);
        break;
      case 2:
        rows = min(8, 6 + ((level - 35) ~/ 15));
        cols = 7 + (level % 2);
        break;
      case 3:
        rows = min(9, 7 + ((level - 75) ~/ 15));
        cols = 7 + ((level ~/ 2) % 3);
        break;
      case 4:
        rows = min(10, 7 + ((level - 115) ~/ 12));
        cols = 8 + (level % 2);
        break;
      case 5:
        rows = min(11, 8 + ((level - 155) ~/ 12));
        cols = 8 + ((level ~/ 2) % 3);
        break;
      case 6:
      default:
        rows = min(12, 9 + ((level - 195) ~/ 12));
        cols = 8 + ((level ~/ 2) % 3);
        break;
    }

    const gap = 5.0;
    final bw = (screenWidth - (padding * 2) - gap * (cols - 1)) / cols;
    const bh = 22.0;
    final step = level % 10;
    final archetype = _selectArchetype(level, world, step);
    final palette = getWorldPalette(world);

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (!_getArchetypeCell(archetype, r, c, rows, cols, level)) continue;

        // Progressive Difficulty & Steel Placement
        bool isSteel = false;
        bool isHeavySteel = false;
        bool isMover = false;

        if (world == 1 && level >= 20) {
          isSteel = (r == 0 && (c == 0 || c == cols - 1));
        } else if (world == 2) {
          isSteel = (r == 0 && (c == 0 || c == cols - 1) && level % 2 == 0);
          isMover = (r == rows - 1 && c % 3 == 0);
        } else if (world == 3) {
          isSteel = (step >= 6 && r == 0 && (c == 1 || c == cols - 2));
          isMover = (r == rows - 1 && c % 2 == 1);
        } else if (world == 4) {
          isSteel = (step >= 6 && r == rows ~/ 2 && (c == 0 || c == cols - 1));
          isMover = ((r == rows - 1 || r == rows - 2) && (r + c) % 4 == 0);
        } else if (world == 5) {
          isSteel = (step >= 6 && (r == 0 || r == 1) && (c == 0 || c == cols - 1));
          isHeavySteel = isSteel && (level % 3 == 0);
          isMover = (r == rows - 1 && (c % 2 == 0));
        } else if (world == 6) {
          isSteel = (step >= 6 && r == 1 && c % 3 == 0);
          isHeavySteel = isSteel && (level % 2 == 0);
          isMover = ((r == rows - 1 || r == rows - 3) && c % 2 == 1);
        }

        // Dual convoys archetype specific mover setup
        if (archetype == 15 && (r == rows - 1 || r == rows - 3) && !isSteel && !isHeavySteel) {
          isMover = true;
        }

        // Dynamite placement (strategic detonators)
        bool isDynamite = false;
        if (!isSteel && !isHeavySteel) {
          if (archetype == 1) { // DominoChain
            isDynamite = (r + c) % 3 == 0;
          } else if (archetype == 16 && r == rows ~/ 2 && c == cols ~/ 2) { // Vault core
            isDynamite = true;
          } else if (level >= 3 && ((r * 7 + c * 13 + level * 5) % 23 == 0)) {
            isDynamite = true;
          }
        }

        // Ice placement (chain freeze cascade)
        bool isIce = false;
        if (!isSteel && !isHeavySteel && !isDynamite) {
          if (archetype == 4 && (r == 0 || r == 1)) { // Ice Avalanche
            isIce = true;
          } else if (level >= 4 && ((r * 11 + c * 17 + level * 7) % 27 == 0)) {
            isIce = true;
          }
        }

        // HP Scaling
        int hp = 1;
        if (isSteel) {
          hp = 999;
        } else if (isHeavySteel) {
          hp = 9999;
        } else if (isIce || isDynamite) {
          hp = 1;
        } else {
          switch (world) {
            case 1:
              hp = (r < 2 && level > 15) ? 2 : 1;
              break;
            case 2:
              hp = (r < 2) ? 2 : ((r == 2 && c % 2 == 0) ? 3 : 1);
              break;
            case 3:
              hp = (r < 3) ? 2 : ((c % 2 == 1) ? 3 : 2);
              break;
            case 4:
              hp = (r < 2) ? 3 : ((r < 4) ? 2 : (((r + c) % 3 == 0) ? 4 : 2));
              break;
            case 5:
              hp = (r < 3) ? 3 : (((r + c) % 2 == 0) ? 4 : 3);
              if (r == rows ~/ 2 && c == cols ~/ 2) hp = 5;
              break;
            case 6:
            default:
              hp = (r < 4) ? 4 : (((r + c) % 2 == 0) ? 5 : 3);
              break;
          }
        }

        final color = isSteel
            ? const Color(0xFF78909C)
            : isHeavySteel
                ? const Color(0xFF37474F)
                : palette[(r + c + (level ~/ 10)) % palette.length];

        final brickX = padding + c * (bw + gap);
        final brickY = baseTopMargin + r * (bh + gap);
        final moverDirection = (r % 2 == 0) ? 1.0 : -1.0;

        bricks.add(
          Brick(
            x: brickX,
            y: brickY,
            width: bw,
            height: bh,
            hp: hp,
            maxHp: hp,
            isSteel: isSteel,
            isHeavySteel: isHeavySteel,
            isMover: isMover,
            moverVx: (60.0 + world * 10.0) * moverDirection,
            isDynamite: isDynamite,
            isIce: isIce,
            minX: padding,
            maxX: screenWidth - padding,
            color: (hp > 1 && !isSteel && !isHeavySteel) ? color.withValues(alpha: 0.85) : color,
            points: (isSteel || isHeavySteel) ? 0 : (25 * hp),
          ),
        );
      }
    }

    // Safety check: ensure at least 6 breakable bricks exist on every level!
    final breakableCount = bricks.where((b) => !b.isSteel && !b.isHeavySteel).length;
    if (breakableCount < 6) {
      final safeRow = rows ~/ 2;
      for (int c = 0; c < cols; c++) {
        final brickX = padding + c * (bw + gap);
        final brickY = baseTopMargin + safeRow * (bh + gap);
        bricks.add(
          Brick(
            x: brickX,
            y: brickY,
            width: bw,
            height: bh,
            hp: 1,
            maxHp: 1,
            minX: padding,
            maxX: screenWidth - padding,
            color: palette[c % palette.length],
            points: 25,
          ),
        );
      }
    }

    // Ensure all bricks are safely clamped within screen width
    for (final b in bricks) {
      if (b.x < padding) b.x = padding;
      if (b.x + b.width > screenWidth - padding) {
        b.x = screenWidth - padding - b.width;
      }
      b.minX = padding;
      b.maxX = screenWidth - padding;
    }

    _applyDecadeSignature(bricks, level);
    return bricks;
  }

  static final Random _descendRand = Random();

  static List<Brick> buildZenLevel(double screenWidth, double screenHeight, [Random? optionalRand]) {
    final rand = optionalRand ?? Random();
    final List<Brick> bricks = [];
    const rows = 4;
    const cols = 6;
    const gap = 8.0;
    final bw = (screenWidth - 36 - gap * (cols - 1)) / cols;
    final totalW = cols * bw + gap * (cols - 1);
    final startX = (screenWidth - totalW) / 2;
    const bh = 24.0;

    // Pick 2 dynamite and 2 ice blocks across the 24 bricks
    final totalBricks = rows * cols;
    final dyn1 = rand.nextInt(totalBricks);
    final dyn2 = (dyn1 + 11) % totalBricks;
    final ice1 = (dyn1 + 5) % totalBricks;
    final ice2 = (dyn1 + 17) % totalBricks;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final index = r * cols + c;
        final color = candyPalette[index % candyPalette.length];
        final isDynamite = (index == dyn1 || index == dyn2);
        final isIce = !isDynamite && (index == ice1 || index == ice2);

        bricks.add(
          Brick(
            x: startX + c * (bw + gap),
            y: baseTopMargin + r * (bh + gap),
            width: bw,
            height: bh,
            hp: 1,
            maxHp: 1,
            isDynamite: isDynamite,
            isIce: isIce,
            color: color,
            points: 10,
          ),
        );
      }
    }
    return bricks;
  }

  static List<Brick> buildDescendInitial(double screenWidth, double screenHeight) {
    final List<Brick> bricks = [];
    const rows = 4;
    for (int r = 0; r < rows; r++) {
      bricks.addAll(buildDescendRow(r, screenWidth, screenHeight));
    }
    return bricks;
  }

  static List<Brick> buildDescendRow(int rowIndex, double screenWidth, double screenHeight, [Random? optionalRand]) {
    final rand = optionalRand ?? _descendRand;
    final List<Brick> rowBricks = [];
    const cols = 7;
    const gap = 6.0;
    final bw = (screenWidth - 32 - gap * (cols - 1)) / cols;
    final totalW = cols * bw + gap * (cols - 1);
    final startX = (screenWidth - totalW) / 2;
    const bh = 22.0;
    const rowStep = bh + gap; // 28.0

    final color = magmaPalette[rowIndex % magmaPalette.length];

    // Balanced chance for dynamite and ice blocks (~28% each per row)
    final spawnDynamite = rand.nextDouble() < 0.28;
    final spawnIce = rand.nextDouble() < 0.28;
    final dynCol = spawnDynamite ? rand.nextInt(cols) : -1;
    final iceCol = spawnIce ? ((dynCol + 1 + rand.nextInt(cols - 1)) % cols) : -1;

    for (int c = 0; c < cols; c++) {
      final isDynamite = c == dynCol;
      final isIce = !isDynamite && c == iceCol;

      rowBricks.add(
        Brick(
          x: startX + c * (bw + gap),
          y: baseTopMargin + rowIndex * rowStep,
          width: bw,
          height: bh,
          hp: 1,
          maxHp: 1,
          isDynamite: isDynamite,
          isIce: isIce,
          color: color,
          points: 15,
        ),
      );
    }
    return rowBricks;
  }

  static const double chaosGap = 8.0;
  static const double chaosMargin = 12.0;
  static const int chaosCols = 7;
  static const double chaosBrickH = 26.0;
  static const double chaosStep = chaosBrickH + chaosGap;

  static List<Brick> buildChaosLevel(int wave, double screenWidth, double screenHeight) {
    final bricks = <Brick>[];
    const initialRows = 4;
    for (int row = 0; row < initialRows; row++) {
      bricks.addAll(buildChaosRow(wave, row, screenWidth, isInitialBoard: true));
    }
    return bricks;
  }

  static List<Brick> buildChaosRow(int wave, int row, double screenWidth, {bool isInitialBoard = false}) {
    final rand = Random(wave * 20011 + row * 101 + 7);
    final bw = (screenWidth - chaosMargin * 2 - chaosGap * (chaosCols - 1)) / chaosCols;
    final y = baseTopMargin + row * chaosStep;
    final bricks = <Brick>[];

    // Pick 1 column for guaranteed +1 Ball pickup per row
    final pickupCol = rand.nextInt(chaosCols);
    // Pick 1-2 empty corridor columns for trick shot ricochets
    final emptyCol1 = (pickupCol + 2) % chaosCols;
    final emptyCol2 = (pickupCol + 4) % chaosCols;

    final bool isBossWaveRow = wave >= 10 && wave % 10 == 0 && row == 0;
    final int bossCol = (pickupCol + 1) % chaosCols;

    for (int c = 0; c < chaosCols; c++) {
      if (c == pickupCol) {
        // Collectible +1 Ball Orb
        bricks.add(
          Brick(
            x: chaosMargin + c * (bw + chaosGap),
            y: y,
            width: bw,
            height: chaosBrickH,
            hp: 1,
            maxHp: 1,
            isBallPickup: true,
            type: BrickType.ballPickup,
            color: const Color(0xFF00E5FF),
            points: 10,
          ),
        );
        continue;
      }

      if (isBossWaveRow && c == bossCol) {
        final bossHp = 40 + (wave ~/ 10) * 30;
        bricks.add(
          Brick(
            x: chaosMargin + c * (bw + chaosGap),
            y: y,
            width: bw,
            height: chaosBrickH,
            hp: bossHp,
            maxHp: bossHp,
            isBoss: true,
            type: BrickType.boss,
            bossVx: 0.0,
            minX: chaosMargin,
            maxX: screenWidth - chaosMargin,
            color: const Color(0xFFFF1744),
            points: 200,
          ),
        );
        continue;
      }

      if (c == emptyCol1 || (rand.nextDouble() < 0.20 && c != emptyCol2)) {
        // Open lane / corridor for trick shots
        continue;
      }

      // Balanced HP for 3-ball gameplay progression
      final int hp;
      if (wave <= 1) {
        hp = (row == 0) ? (1 + rand.nextInt(2)) : (1 + rand.nextInt(3));
      } else if (wave <= 3) {
        hp = 2 + rand.nextInt(3);
      } else {
        hp = (wave - 1) + rand.nextInt(4);
      }

      final colorIndex = (wave * 3 + row * 2 + c) % neonPalette.length;
      final color = neonPalette[colorIndex];

      bricks.add(
        Brick(
          x: chaosMargin + c * (bw + chaosGap),
          y: y,
          width: bw,
          height: chaosBrickH,
          hp: hp,
          maxHp: hp,
          color: color,
          points: 5,
        ),
      );
    }
    return bricks;
  }

  static List<Brick> buildDailyLevel(DateTime date, double screenWidth, double screenHeight) {
    final seed = date.year * 1000 + date.month * 100 + date.day;
    final rand = Random(seed);
    final List<Brick> bricks = [];
    const rows = 5;
    const cols = 7;
    const gap = 6.0;
    final bw = (screenWidth - 36 - gap * (cols - 1)) / cols;
    final totalW = cols * bw + gap * (cols - 1);
    final startX = (screenWidth - totalW) / 2;
    final bh = 22.0;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (rand.nextDouble() > 0.18) {
          final isSteel = (r == 1 && (c == 2 || c == 4));
          final color = icePalette[rand.nextInt(icePalette.length)];
          bricks.add(
            Brick(
              x: startX + c * (bw + gap),
              y: baseTopMargin + r * (bh + gap),
              width: bw,
              height: bh,
              hp: isSteel ? 999 : (rand.nextBool() ? 2 : 1),
              maxHp: isSteel ? 999 : 2,
              isSteel: isSteel,
              color: isSteel ? const Color(0xFFCFD8DC) : color,
              points: 25,
            ),
          );
        }
      }
    }
    return bricks;
  }

  static const List<String> shapeNamesTr = [
    'Kalp',         // 1
    'Kuru Kafa',    // 2
    'Kılıç',        // 3
    'Elmas',        // 4
    'Gülen Yüz',    // 5
    'Yıldız',       // 6
    'Roket',        // 7
    'Taç',          // 8
    'Hayalet',      // 9
    'Mantar',       // 10
    'Gamepad',      // 11
    'Şimşek',       // 12
    'Balık',        // 13
    'Çapa',         // 14
    'Kalkan',       // 15
    'Kupa',         // 16
    'Anahtar',      // 17
    'Çam Ağacı',    // 18
    'Çan',          // 19
    'Hazine Sandığı', // 20
    'Uzay Gemisi',  // 21
    'Kiraz',        // 22
    'Alev',         // 23
    'Kar Tanesi',   // 24
    'Güneş',        // 25
    'Hilal',        // 26
    'Elma',         // 27
    'Kanca',        // 28
    'Kristal',      // 29
    'Bomba',        // 30
    'Müzik Notası', // 31
    'Bayrak',       // 32
    'Kum Saati',    // 33
    'Büyüteç',      // 34
    'Yüzük',        // 35
    'Kilitli Kalp', // 36
    'Sonsuzluk',    // 37
    'Ejderha',      // 38
  ];

  static const List<String> shapeNamesEn = [
    'Heart',        // 1
    'Skull',        // 2
    'Sword',        // 3
    'Diamond',      // 4
    'Smiley',       // 5
    'Star',         // 6
    'Rocket',       // 7
    'Crown',        // 8
    'Ghost',        // 9
    'Mushroom',     // 10
    'Gamepad',      // 11
    'Lightning',    // 12
    'Fish',         // 13
    'Anchor',       // 14
    'Shield',       // 15
    'Trophy',       // 16
    'Key',          // 17
    'Pine Tree',    // 18
    'Bell',         // 19
    'Treasure Chest', // 20
    'Space Invader', // 21
    'Cherries',     // 22
    'Flame',        // 23
    'Snowflake',    // 24
    'Sun',          // 25
    'Crescent',     // 26
    'Apple',        // 27
    'Hook',         // 28
    'Crystal',      // 29
    'Bomb',         // 30
    'Music Note',   // 31
    'Flag',         // 32
    'Hourglass',    // 33
    'Magnifier',    // 34
    'Ring',         // 35
    'Heart Lock',   // 36
    'Infinity',     // 37
    'Dragon',       // 38
  ];

  static String getShapeName(int index, {String lang = 'tr'}) {
    final i = index.clamp(0, allShapes.length - 1);
    return lang == 'en' ? shapeNamesEn[i] : shapeNamesTr[i];
  }

  static List<Brick> buildShapesLevel(
    int level,
    double screenWidth,
    double screenHeight, {
    int? explicitShapeIndex,
  }) {
    final List<Brick> bricks = [];
    final shapeIndex = explicitShapeIndex != null
        ? explicitShapeIndex.clamp(0, allShapes.length - 1)
        : (level - 1) % allShapes.length;
    final matrix = allShapes[shapeIndex];
    final rows = matrix.length;
    final cols = matrix[0].length;
    const gap = 6.0;
    final bw = (screenWidth - 40 - gap * (cols - 1)) / cols;
    final totalW = cols * bw + gap * (cols - 1);
    final startX = (screenWidth - totalW) / 2;
    final bh = 22.0;

    // Thematic palette per shape index
    final List<Color> palette;
    switch (shapeIndex) {
      case 0: // Kalp
      case 21: // Kiraz
      case 22: // Alev
      case 26: // Elma
      case 29: // Bomba
        palette = magmaPalette;
        break;
      case 1: // Kuru Kafa (Spooky neon)
      case 10: // Gamepad
      case 11: // Şimşek
      case 20: // Invader
      case 35: // HeartLock
      case 36: // Infinity
      case 37: // Dragon
        palette = neonPalette;
        break;
      case 2: // Kılıç
      case 3: // Elmas
      case 8: // Hayalet
      case 23: // Kar Tanesi
      case 25: // Ay
      case 28: // Gem
        palette = icePalette;
        break;
      case 4: // Gülen Yüz
      case 5: // Yıldız
      case 6: // Roket
      case 7: // Taç
      case 15: // Kupa
      case 16: // Anahtar
      case 18: // Çan
      case 19: // Sandık
      case 24: // Güneş
      case 34: // Yüzük
        palette = goldPalette;
        break;
      case 12: // Balık
      case 13: // Çapa
      case 17: // Ağaç
      case 27: // Kanca
        palette = naturePalette;
        break;
      case 9: // Mantar
      case 14: // Kalkan
      case 30: // Nota
      case 31: // Bayrak
      case 32: // Kum Saati
      case 33: // Büyüteç
      default:
        palette = candyPalette;
        break;
    }

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (matrix[r][c] == 1) {
          final color = palette[(r + c) % palette.length];
          bricks.add(
            Brick(
              x: startX + c * (bw + gap),
              y: baseTopMargin + r * (bh + gap),
              width: bw,
              height: bh,
              hp: 1,
              maxHp: 1,
              color: color,
              points: 20,
            ),
          );
        }
      }
    }
    return bricks;
  }
}
