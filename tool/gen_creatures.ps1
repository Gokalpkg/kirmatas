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

# Downscale to 125px and blow back up with nearest-neighbour so the
# newer creatures share the retro pixel-art texture of the fish set.
function Save-Pixel($bmp, $g, $name) {
    $g.Dispose()
    $small = New-Object System.Drawing.Bitmap(125, 125)
    $sg = [System.Drawing.Graphics]::FromImage($small)
    $sg.InterpolationMode = 'HighQualityBicubic'
    $sg.DrawImage($bmp, 0, 0, 125, 125)
    $big = New-Object System.Drawing.Bitmap(500, 500)
    $bg2 = [System.Drawing.Graphics]::FromImage($big)
    $bg2.InterpolationMode = 'NearestNeighbor'
    $bg2.PixelOffsetMode = 'None'
    $bg2.DrawImage($small, 0, 0, 500, 500)
    $big.Save("$outDir\$name", 'Png')
    $sg.Dispose(); $small.Dispose(); $bg2.Dispose(); $big.Dispose(); $bmp.Dispose()
}

$white = New-Object System.Drawing.SolidBrush((C 255 255 255 255))
$black = New-Object System.Drawing.SolidBrush((C 255 38 30 28))
$hl = New-Object System.Drawing.SolidBrush((C 90 255 255 255))
$blush = New-Object System.Drawing.SolidBrush((C 110 255 138 128))
$spot = New-Object System.Drawing.SolidBrush((C 70 255 255 255))

# ---------------- SNAIL (Golden Apple Snail) ----------------
$bmp, $g = New-Canvas
# foot / body: long flat sole creeping to the right
$footBrush = GradBrush 78 300 330 92 (C 255 255 213 141) (C 255 230 160 90)
$footPath = New-Object System.Drawing.Drawing2D.GraphicsPath
$footPath.AddEllipse(78, 316, 300, 66)
$g.FillPath($footBrush, $footPath)
# head, slightly raised at the front
$g.FillEllipse($footBrush, 316, 282, 86, 76)
# foot speckle texture
$speck = New-Object System.Drawing.SolidBrush((C 90 214 150 80))
foreach ($sp in @(@(140, 348, 9), @(196, 358, 7), @(252, 350, 8), @(300, 360, 6), @(342, 330, 7))) {
    $g.FillEllipse($speck, $sp[0], $sp[1], $sp[2], $sp[2])
}
# breathing siphon tube rising behind the head
$siphonPen = New-Object System.Drawing.Pen((C 255 244 190 120), 13)
$siphonPen.StartCap = 'Round'; $siphonPen.EndCap = 'Round'
$siphonPath = New-Object System.Drawing.Drawing2D.GraphicsPath
$siphonPath.AddBezier(322, 296, 300, 250, 292, 218, 278, 184)
$g.DrawPath($siphonPen, $siphonPath)
# two long cephalic tentacles + short labial palps
$tentPenS = New-Object System.Drawing.Pen((C 255 248 200 130), 9)
$tentPenS.StartCap = 'Round'; $tentPenS.EndCap = 'Round'
$tPath1 = New-Object System.Drawing.Drawing2D.GraphicsPath
$tPath1.AddBezier(356, 292, 372, 248, 388, 218, 410, 196)
$g.DrawPath($tentPenS, $tPath1)
$tPath2 = New-Object System.Drawing.Drawing2D.GraphicsPath
$tPath2.AddBezier(344, 298, 350, 256, 356, 226, 372, 198)
$g.DrawPath($tentPenS, $tPath2)
$g.DrawLine($tentPenS, 372, 316, 398, 306)
# eyes sit at the base of the long tentacles (apple snail anatomy)
$eyeB = New-Object System.Drawing.SolidBrush((C 255 62 39 35))
$g.FillEllipse($eyeB, 350, 282, 11, 13)
$g.FillEllipse($eyeB, 338, 288, 10, 12)
# shell: big golden dome with amber growth bands
$shellBrush = GradBrush 84 96 258 252 (C 255 255 214 120) (C 255 196 120 40)
$g.FillEllipse($shellBrush, 84, 96, 258, 252)
$bandPen = New-Object System.Drawing.Pen((C 170 160 90 30), 13)
foreach ($bd in @(@(104, 118, 218, 212), @(130, 146, 168, 162), @(156, 174, 118, 112))) {
    $g.DrawEllipse($bandPen, $bd[0], $bd[1], $bd[2], $bd[3])
}
# spire whorls tightening toward the apex
$spirePen = New-Object System.Drawing.Pen((C 200 146 78 26), 9)
$spirePen.StartCap = 'Round'; $spirePen.EndCap = 'Round'
$pts = @()
for ($i = 0; $i -le 60; $i++) {
    $t = $i / 60.0
    $ang = $t * 11.0 + 0.6
    $rad = 62.0 * (1.0 - $t * 0.8)
    $pts += New-Object System.Drawing.PointF((196 + [Math]::Cos($ang) * $rad), (196 + [Math]::Sin($ang) * $rad * 0.92))
}
$g.DrawLines($spirePen, $pts)
# aperture shadow where the body leaves the shell
$aper = New-Object System.Drawing.SolidBrush((C 160 120 66 20))
$g.FillEllipse($aper, 288, 238, 58, 104)
# shell rim + light
$rimPen = New-Object System.Drawing.Pen((C 255 141 80 22), 7)
$g.DrawEllipse($rimPen, 84, 96, 258, 252)
$g.FillEllipse($hl, 138, 128, 62, 32)
Save-Pixel $bmp $g 'snail.png'

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

# ---------------- OCTOPUS (natural) ----------------
$bmp, $g = New-Canvas
$armPen = New-Object System.Drawing.Pen((C 255 106 62 148), 26)
$armPen.StartCap = 'Round'; $armPen.EndCap = 'Round'
# rear arms curling out beneath the mantle
foreach ($tp in @(@(196, 306, 148, 344, 118, 398), @(228, 318, 196, 372, 172, 420), @(292, 318, 316, 374, 344, 414), @(318, 304, 366, 338, 402, 384))) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddBezier($tp[0], $tp[1], $tp[2], $tp[3], $tp[4], $tp[5], $tp[4], $tp[5])
    $g.DrawPath($armPen, $path)
}
# mantle: tall natural dome, violet with darker mottling
$mantleBrush = GradBrush 158 78 190 240 (C 255 171 120 205) (C 255 94 53 140)
$mantlePath = New-Object System.Drawing.Drawing2D.GraphicsPath
$mantlePath.AddEllipse(158, 78, 190, 244)
$g.FillPath($mantleBrush, $mantlePath)
$mottle = New-Object System.Drawing.SolidBrush((C 60 74 40 110))
foreach ($sp in @(@(196, 128, 22), @(268, 106, 16), @(306, 168, 19), @(208, 196, 14), @(282, 226, 15), @(238, 154, 12))) {
    $g.FillEllipse($mottle, $sp[0], $sp[1], $sp[2], $sp[2] * 0.7)
}
$g.FillEllipse($hl, 192, 102, 56, 28)
# funnel (siphon) poking out on the left of the mantle base
$funPen = New-Object System.Drawing.Pen((C 255 128 84 168), 15)
$funPen.StartCap = 'Round'; $funPen.EndCap = 'Round'
$g.DrawLine($funPen, 178, 268, 148, 292)
# front arms with double rows of pale suckers
$armPenF = New-Object System.Drawing.Pen((C 255 124 77 168), 24)
$armPenF.StartCap = 'Round'; $armPenF.EndCap = 'Round'
$frontArms = @(
    @(206, 316, 182, 362, 152, 392),
    @(244, 324, 238, 376, 224, 420),
    @(282, 324, 292, 376, 306, 418),
    @(312, 312, 340, 354, 372, 384)
)
foreach ($tp in $frontArms) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddBezier($tp[0], $tp[1], $tp[2], $tp[3], $tp[4], $tp[5], $tp[4], $tp[5])
    $g.DrawPath($armPenF, $path)
}
$sucker = New-Object System.Drawing.SolidBrush((C 205 230 200 240))
foreach ($tp in $frontArms) {
    for ($i = 1; $i -le 3; $i++) {
        $t = $i / 4.0
        $mt = 1.0 - $t
        $px = $mt*$mt*$tp[0] + 2*$mt*$t*$tp[2] + $t*$t*$tp[4]
        $py = $mt*$mt*$tp[1] + 2*$mt*$t*$tp[3] + $t*$t*$tp[5]
        $sz = 10 - $i * 1.6
        $g.FillEllipse($sucker, ($px - $sz/2), ($py - $sz/2), $sz, $sz)
    }
}
# eyes at the mantle base: white eye with the octopus' horizontal pupil
$g.FillEllipse($white, 196, 268, 30, 20)
$g.FillEllipse($white, 282, 268, 30, 20)
$pupil = New-Object System.Drawing.SolidBrush((C 255 30 16 40))
$g.FillRectangle($pupil, 200, 275, 22, 7)
$g.FillRectangle($pupil, 286, 275, 22, 7)
Save-Pixel $bmp $g 'octopus.png'

# ---------------- JELLYFISH (Moon Jelly) ----------------
$bmp, $g = New-Canvas
# many fine marginal tentacles trailing from the bell rim
$tentPen = New-Object System.Drawing.Pen((C 190 190 226 252), 5)
$tentPen.StartCap = 'Round'; $tentPen.EndCap = 'Round'
foreach ($tx in @(150, 178, 206, 234, 262, 290, 318, 346)) {
    $pts = @()
    for ($i = 0; $i -le 24; $i++) {
        $t = $i / 24.0
        $wave = [Math]::Sin($t * 8.0 + $tx * 0.7) * (5.0 + $t * 16.0)
        $pts += New-Object System.Drawing.PointF(($tx + $wave), (252 + $t * 178.0))
    }
    $g.DrawLines($tentPen, $pts)
}
# four frilly oral arms hanging from the centre
$armPen = New-Object System.Drawing.Pen((C 215 244 178 216), 13)
$armPen.StartCap = 'Round'; $armPen.EndCap = 'Round'
foreach ($tx in @(222, 246, 270, 294)) {
    $pts = @()
    for ($i = 0; $i -le 20; $i++) {
        $t = $i / 20.0
        $wave = [Math]::Sin($t * 10.0 + $tx) * (4.0 + $t * 10.0)
        $pts += New-Object System.Drawing.PointF(($tx + $wave), (256 + $t * 108.0))
    }
    $g.DrawLines($armPen, $pts)
}
# translucent bell with a scalloped rim
$bellPath = New-Object System.Drawing.Drawing2D.GraphicsPath
$bellPath.AddArc(112, 108, 276, 224, 180, 180)
$rimY = 224.0
for ($i = 0; $i -lt 7; $i++) {
    $sx = 112.0 + $i * 39.4
    $bellPath.AddArc($sx, ($rimY - 10), 40, 20, 0, 180)
}
$bellPath.CloseFigure()
$bellBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.RectangleF(112, 100, 276, 210)),
    (C 178 214 240 252), (C 165 226 168 232), 90.0)
$g.FillPath($bellBrush, $bellPath)
$bellPen = New-Object System.Drawing.Pen((C 190 168 132 205), 5)
$g.DrawPath($bellPen, $bellPath)
# the moon jelly signature: four horseshoe gonad rings under the bell
$gonadPen = New-Object System.Drawing.Pen((C 215 236 140 196), 11)
foreach ($gp in @(@(196, 138), @(258, 130), @(204, 182), @(262, 176))) {
    $g.DrawEllipse($gonadPen, $gp[0], $gp[1], 44, 30)
}
# radial canals running from the stomach to the rim
$canalPen = New-Object System.Drawing.Pen((C 120 190 220 245), 4)
foreach ($cx in @(140, 190, 250, 310, 360)) {
    $g.DrawLine($canalPen, 250, 176, $cx, 226)
}
# soft light through the top of the bell
$core = New-Object System.Drawing.SolidBrush((C 90 255 255 255))
$g.FillEllipse($core, 182, 116, 130, 62)
Save-Pixel $bmp $g 'jellyfish.png'

Write-Output 'creatures generated'
