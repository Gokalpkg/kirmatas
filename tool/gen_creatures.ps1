Add-Type -AssemblyName System.Drawing

function New-Canvas {
    $bmp = New-Object System.Drawing.Bitmap(500, 500)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.PixelOffsetMode = 'HighQuality'
    return @($bmp, $g)
}

function C([int]$a, [int]$r, [int]$gg, [int]$b) {
    return [System.Drawing.Color]::FromArgb($a, $r, $gg, $b)
}

function GradBrush($x, $y, $w, $h, $c1, $c2) {
    $rect = New-Object System.Drawing.RectangleF($x, $y, $w, $h)
    return New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $c1, $c2, 90.0)
}

$outDir = 'assets\images\fishes'

# ---------------- SNAIL ----------------
$bmp, $g = New-Canvas
# eye stalks
$stalkPen = New-Object System.Drawing.Pen((C 255 255 204 128), 13)
$stalkPen.StartCap = 'Round'; $stalkPen.EndCap = 'Round'
$g.DrawLine($stalkPen, 330, 300, 352, 226)
$g.DrawLine($stalkPen, 306, 302, 312, 222)
# foot / body
$bodyBrush = GradBrush 105 285 260 105 (C 255 255 224 178) (C 255 255 167 116)
$g.FillEllipse($bodyBrush, 105, 292, 250, 82)
$headBrush = New-Object System.Drawing.SolidBrush((C 255 255 204 150))
$g.FillEllipse($headBrush, 298, 266, 80, 80)
# shell
$shellBrush = GradBrush 128 168 190 190 (C 255 188 143 118) (C 255 109 76 65)
$g.FillEllipse($shellBrush, 128, 168, 192, 192)
$rimPen = New-Object System.Drawing.Pen((C 255 93 64 55), 7)
$g.DrawEllipse($rimPen, 128, 168, 192, 192)
# spiral
$pts = @()
for ($i = 0; $i -le 60; $i++) {
    $t = $i / 60.0
    $ang = $t * 12.0
    $rad = 78.0 * (1.0 - $t * 0.82)
    $pts += New-Object System.Drawing.PointF((224 + [Math]::Cos($ang) * $rad), (264 + [Math]::Sin($ang) * $rad))
}
$spiralPen = New-Object System.Drawing.Pen((C 230 121 85 72), 11)
$spiralPen.StartCap = 'Round'; $spiralPen.EndCap = 'Round'
$g.DrawLines($spiralPen, $pts)
# shell highlight
$hl = New-Object System.Drawing.SolidBrush((C 90 255 255 255))
$g.FillEllipse($hl, 168, 196, 52, 30)
# eyes
$white = New-Object System.Drawing.SolidBrush((C 255 255 255 255))
$black = New-Object System.Drawing.SolidBrush((C 255 38 30 28))
$g.FillEllipse($white, 338, 206, 30, 30)
$g.FillEllipse($white, 298, 202, 30, 30)
$g.FillEllipse($black, 346, 214, 15, 15)
$g.FillEllipse($black, 306, 210, 15, 15)
# smile + blush
$smilePen = New-Object System.Drawing.Pen((C 255 160 120 90), 5)
$smilePen.StartCap = 'Round'; $smilePen.EndCap = 'Round'
$g.DrawArc($smilePen, 326, 300, 26, 18, 20, 110)
$blush = New-Object System.Drawing.SolidBrush((C 110 255 138 128))
$g.FillEllipse($blush, 306, 296, 24, 14)
$bmp.Save("$outDir\snail.png", 'Png')
$g.Dispose(); $bmp.Dispose()

# ---------------- SHRIMP ----------------
$bmp, $g = New-Canvas
# antennae (behind body)
$antPen = New-Object System.Drawing.Pen((C 220 255 171 145), 7)
$antPen.StartCap = 'Round'; $antPen.EndCap = 'Round'
$antPath = New-Object System.Drawing.Drawing2D.GraphicsPath
$antPath.AddBezier(338, 196, 250, 120, 130, 118, 62, 168)
$antPath.AddBezier(342, 210, 268, 152, 168, 140, 96, 120)
$g.DrawPath($antPen, $antPath)
# legs
$legPen = New-Object System.Drawing.Pen((C 255 216 67 21), 8)
$legPen.StartCap = 'Round'; $legPen.EndCap = 'Round'
foreach ($lp in @(@(268, 296, 252, 330), @(232, 306, 210, 336), @(196, 308, 168, 332))) {
    $g.DrawLine($legPen, $lp[0], $lp[1], $lp[2], $lp[3])
}
# tail fan
$tailBrush = New-Object System.Drawing.SolidBrush((C 255 255 112 67))
$fan = New-Object System.Drawing.Drawing2D.GraphicsPath
$fan.AddPolygon(@(
    (New-Object System.Drawing.PointF(158, 288)),
    (New-Object System.Drawing.PointF(96, 250)),
    (New-Object System.Drawing.PointF(88, 292)),
    (New-Object System.Drawing.PointF(96, 334)),
    (New-Object System.Drawing.PointF(158, 316))
))
$g.FillPath($tailBrush, $fan)
# body segments along a curve (tail -> head)
$segs = @(
    @(168, 296, 44), @(196, 282, 52), @(228, 264, 58), @(258, 242, 62),
    @(284, 218, 64), @(306, 196, 62), @(330, 182, 56)
)
foreach ($s in $segs) {
    $sb = GradBrush ($s[0] - $s[2] / 2) ($s[1] - $s[2] / 2) $s[2] $s[2] (C 255 255 138 101) (C 255 230 74 25)
    $g.FillEllipse($sb, $s[0] - $s[2] / 2, $s[1] - $s[2] / 2, $s[2], $s[2])
}
# segment stripes
$stripePen = New-Object System.Drawing.Pen((C 160 255 204 188), 5)
foreach ($s in $segs[0..4]) {
    $g.DrawArc($stripePen, $s[0] - $s[2] / 2, $s[1] - $s[2] / 2, $s[2], $s[2], 300, 90)
}
# head highlight + eye
$g.FillEllipse($white, 330, 158, 17, 12)
$g.FillEllipse($black, 344, 168, 19, 19)
$g.FillEllipse($white, 350, 172, 6, 6)
$bmp.Save("$outDir\shrimp.png", 'Png')
$g.Dispose(); $bmp.Dispose()

# ---------------- CRAB ----------------
$bmp, $g = New-Canvas
$legPen2 = New-Object System.Drawing.Pen((C 255 183 28 28), 15)
$legPen2.StartCap = 'Round'; $legPen2.EndCap = 'Round'
# legs: 3 per side, bent
foreach ($lp in @(@(168, 300, 108, 330, 76, 316), @(176, 318, 122, 356, 96, 356), @(196, 332, 156, 374, 140, 386))) {
    $ptsL = @((New-Object System.Drawing.PointF($lp[0], $lp[1])), (New-Object System.Drawing.PointF($lp[2], $lp[3])), (New-Object System.Drawing.PointF($lp[4], $lp[5])))
    $g.DrawLines($legPen2, $ptsL)
}
foreach ($lp in @(@(322, 300, 384, 330, 418, 314), @(314, 318, 370, 356, 398, 354), @(294, 332, 336, 374, 352, 386))) {
    $ptsL = @((New-Object System.Drawing.PointF($lp[0], $lp[1])), (New-Object System.Drawing.PointF($lp[2], $lp[3])), (New-Object System.Drawing.PointF($lp[4], $lp[5])))
    $g.DrawLines($legPen2, $ptsL)
}
# small claw (left)
$clawBrush = GradBrush 96 218 96 96 (C 255 255 82 82) (C 255 198 40 40)
$g.FillEllipse($clawBrush, 100, 222, 74, 66)
# body
$bodyBrush2 = GradBrush 138 196 224 148 (C 255 255 96 96) (C 255 198 40 40)
$g.FillEllipse($bodyBrush2, 138, 198, 224, 146)
# big claw (right): pac-man path
$clawPath = New-Object System.Drawing.Drawing2D.GraphicsPath
$clawPath.AddArc(330, 208, 104, 96, -38, 300)
$clawPath.AddLine(382, 256, 352, 268)
$clawPath.CloseFigure()
$clawBrush2 = GradBrush 330 208 104 96 (C 255 255 112 112) (C 255 183 28 28)
$g.FillPath($clawBrush2, $clawPath)
# body highlight + spots
$g.FillEllipse($hl, 176, 216, 84, 34)
$spot = New-Object System.Drawing.SolidBrush((C 70 255 255 255))
$g.FillEllipse($spot, 300, 236, 20, 13)
$g.FillEllipse($spot, 168, 268, 15, 10)
# eye stalks + eyes
$stalkPen2 = New-Object System.Drawing.Pen((C 255 198 40 40), 11)
$stalkPen2.StartCap = 'Round'; $stalkPen2.EndCap = 'Round'
$g.DrawLine($stalkPen2, 224, 206, 218, 168)
$g.DrawLine($stalkPen2, 262, 206, 268, 168)
$g.FillEllipse($white, 202, 142, 32, 32)
$g.FillEllipse($white, 252, 142, 32, 32)
$g.FillEllipse($black, 211, 152, 16, 16)
$g.FillEllipse($black, 261, 152, 16, 16)
# smile
$smilePen2 = New-Object System.Drawing.Pen((C 255 120 20 20), 7)
$smilePen2.StartCap = 'Round'; $smilePen2.EndCap = 'Round'
$g.DrawArc($smilePen2, 222, 262, 44, 30, 15, 150)
$bmp.Save("$outDir\crab.png", 'Png')
$g.Dispose(); $bmp.Dispose()

# ---------------- OCTOPUS ----------------
$bmp, $g = New-Canvas
$tentPen = New-Object System.Drawing.Pen((C 255 126 87 194), 30)
$tentPen.StartCap = 'Round'; $tentPen.EndCap = 'Round'
# back tentacles
foreach ($tp in @(@(196, 300, 150, 350, 128, 396), @(226, 312, 200, 366, 178, 408), @(316, 306, 356, 352, 392, 388), @(288, 314, 300, 372, 330, 410))) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddBezier($tp[0], $tp[1], $tp[2], $tp[3], $tp[2], $tp[3], $tp[4], $tp[5])
    $g.DrawPath($tentPen, $path)
}
# head dome
$headBrush = GradBrush 150 118 210 216 (C 255 206 147 216) (C 255 142 36 170)
$headPath = New-Object System.Drawing.Drawing2D.GraphicsPath
$headPath.AddEllipse(150, 118, 210, 216)
$g.FillPath($headBrush, $headPath)
# front tentacles
foreach ($tp in @(@(208, 316, 186, 362, 158, 388), @(262, 322, 262, 372, 246, 404), @(306, 314, 330, 360, 362, 380))) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddBezier($tp[0], $tp[1], $tp[2], $tp[3], $tp[2], $tp[3], $tp[4], $tp[5])
    $g.DrawPath($tentPen, $path)
}
# suckers on front tentacles
$sucker = New-Object System.Drawing.SolidBrush((C 200 243 229 245))
foreach ($sp in @(@(190, 356, 11), @(172, 380, 10), @(258, 366, 11), @(252, 392, 10), @(330, 354, 11), @(352, 372, 10))) {
    $g.FillEllipse($sucker, $sp[0], $sp[1], $sp[2], $sp[2])
}
# spots + highlight
$g.FillEllipse($spot, 196, 160, 26, 17)
$g.FillEllipse($spot, 306, 186, 19, 13)
$g.FillEllipse($hl, 196, 140, 62, 30)
# eyes
$g.FillEllipse($white, 196, 226, 42, 46)
$g.FillEllipse($white, 268, 226, 42, 46)
$g.FillEllipse($black, 208, 240, 21, 25)
$g.FillEllipse($black, 280, 240, 21, 25)
$g.FillEllipse($white, 214, 244, 7, 8)
$g.FillEllipse($white, 286, 244, 7, 8)
# mouth + blush
$mouthPen = New-Object System.Drawing.Pen((C 255 106 27 154), 6)
$mouthPen.StartCap = 'Round'; $mouthPen.EndCap = 'Round'
$g.DrawArc($mouthPen, 240, 262, 26, 18, 15, 150)
$g.FillEllipse($blush, 178, 268, 28, 16)
$g.FillEllipse($blush, 306, 268, 28, 16)
$bmp.Save("$outDir\octopus.png", 'Png')
$g.Dispose(); $bmp.Dispose()

# ---------------- JELLYFISH ----------------
$bmp, $g = New-Canvas
# tentacles (long wavy strands hanging from the bell)
$tentPen = New-Object System.Drawing.Pen((C 235 206 147 216), 8)
$tentPen.StartCap = 'Round'; $tentPen.EndCap = 'Round'
foreach ($tx in @(168, 208, 250, 292, 332)) {
    $pts = @()
    for ($i = 0; $i -le 24; $i++) {
        $t = $i / 24.0
        $wave = [Math]::Sin($t * 9.0 + $tx) * (6.0 + $t * 14.0)
        $pts += New-Object System.Drawing.PointF(($tx + $wave), (292 + $t * 148.0))
    }
    $g.DrawLines($tentPen, $pts)
}
# frilly oral arms (shorter, thicker, ruffled)
$armPen = New-Object System.Drawing.Pen((C 245 244 143 177), 15)
$armPen.StartCap = 'Round'; $armPen.EndCap = 'Round'
foreach ($tx in @(218, 250, 282)) {
    $pts = @()
    for ($i = 0; $i -le 20; $i++) {
        $t = $i / 20.0
        $wave = [Math]::Sin($t * 11.0 + $tx * 2.0) * (5.0 + $t * 9.0)
        $pts += New-Object System.Drawing.PointF(($tx + $wave), (296 + $t * 92.0))
    }
    $g.DrawLines($armPen, $pts)
}
# bell (dome) with scalloped rim
$bellPath = New-Object System.Drawing.Drawing2D.GraphicsPath
$bellPath.AddArc(118, 118, 264, 216, 180, 180)
$rimY = 226.0
for ($i = 0; $i -lt 6; $i++) {
    $sx = 118.0 + $i * 44.0
    $bellPath.AddArc($sx, ($rimY - 12), 44, 24, 0, 180)
}
$bellPath.CloseFigure()
$bellBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.RectangleF(118, 110, 264, 200)),
    (C 255 248 187 208), (C 255 186 104 200), 90.0)
$g.FillPath($bellBrush, $bellPath)
$bellPen = New-Object System.Drawing.Pen((C 255 171 71 188), 6)
$g.DrawPath($bellPen, $bellPath)
# inner bell glow core
$core = New-Object System.Drawing.SolidBrush((C 120 255 236 250))
$g.FillEllipse($core, 178, 150, 144, 92)
# glow spots on the bell
$spotJ = New-Object System.Drawing.SolidBrush((C 150 255 255 255))
$g.FillEllipse($spotJ, 168, 176, 22, 15)
$g.FillEllipse($spotJ, 316, 196, 17, 12)
$g.FillEllipse($spotJ, 282, 146, 14, 10)
# highlight
$hlJ = New-Object System.Drawing.SolidBrush((C 120 255 255 255))
$g.FillEllipse($hlJ, 168, 132, 66, 30)
# happy closed eyes (arcs) + smile + blush
$facePen = New-Object System.Drawing.Pen((C 255 123 31 162), 7)
$facePen.StartCap = 'Round'; $facePen.EndCap = 'Round'
$g.DrawArc($facePen, 196, 200, 30, 20, 180, 180)
$g.DrawArc($facePen, 274, 200, 30, 20, 180, 180)
$g.DrawArc($facePen, 240, 214, 22, 15, 15, 150)
$blushJ = New-Object System.Drawing.SolidBrush((C 170 244 143 177))
$g.FillEllipse($blushJ, 182, 216, 26, 15)
$g.FillEllipse($blushJ, 292, 216, 26, 15)
$bmp.Save("$outDir\jellyfish.png", 'Png')
$g.Dispose(); $bmp.Dispose()

Write-Output 'creatures generated'
