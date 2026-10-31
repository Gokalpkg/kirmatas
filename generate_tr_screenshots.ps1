Add-Type -AssemblyName System.Drawing

function Create-TrScreenshot($srcPath, $dstPath, $line1, $line2, $subline, $theme) {
    $src = [System.Drawing.Bitmap]::FromFile($srcPath)
    $bmp = New-Object System.Drawing.Bitmap $src.Width, $src.Height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

    # 1. Draw original base image
    $g.DrawImage($src, 0, 0, $src.Width, $src.Height)

    # 2. Theme-specific background overlay colors
    # Default (cosmic / purple-blue space)
    $cSolid = [System.Drawing.Color]::FromArgb(255, 12, 8, 28)
    $cFade = [System.Drawing.Color]::FromArgb(0, 12, 8, 28)
    
    if ($theme -eq "fire") {
        # Fiery volcanic dark red/amber space
        $cSolid = [System.Drawing.Color]::FromArgb(255, 26, 6, 4)
        $cFade = [System.Drawing.Color]::FromArgb(0, 26, 6, 4)
    } elseif ($theme -eq "water") {
        # Deep ocean midnight blue
        $cSolid = [System.Drawing.Color]::FromArgb(255, 4, 18, 48)
        $cFade = [System.Drawing.Color]::FromArgb(0, 4, 18, 48)
    }

    # 3. Completely cover old text from y=0 to y=510 with solid color
    $solidBrush = New-Object System.Drawing.SolidBrush $cSolid
    $g.FillRectangle($solidBrush, 0, 0, $src.Width, 510)
    $solidBrush.Dispose()

    # 4. Soft fade from y=510 to y=560 right above phone bezel
    $pt1 = New-Object System.Drawing.Point 0, 509
    $pt2 = New-Object System.Drawing.Point 0, 560
    $fadeBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $pt1, $pt2, $cSolid, $cFade
    $g.FillRectangle($fadeBrush, 0, 509, $src.Width, 52)
    $fadeBrush.Dispose()

    $fontFamily = New-Object System.Drawing.FontFamily "Arial Black"
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center

    # Helper function to draw text with heavy outline and 3D gradient
    function Draw-TextWithOutline($text, [float]$fontSize, [System.Drawing.RectangleF]$rect, $gradColor1, $gradColor2, $outlineColor, [float]$outlineWidth) {
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $path.AddString($text, $fontFamily, [int][System.Drawing.FontStyle]::Bold, $fontSize, $rect, $sf)

        # Multi-layer deep arcade drop shadow
        for ($s = 14; $s -ge 2; $s -= 2) {
            $shadowPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(85, 0, 0, 0)), ($outlineWidth + $s)
            $matrix = New-Object System.Drawing.Drawing2D.Matrix
            $matrix.Translate(0, $s * 0.75)
            $shadowPath = $path.Clone()
            $shadowPath.Transform($matrix)
            $g.DrawPath($shadowPen, $shadowPath)
            $shadowPen.Dispose()
            $shadowPath.Dispose()
            $matrix.Dispose()
        }

        # Dark Outline
        $pen = New-Object System.Drawing.Pen $outlineColor, $outlineWidth
        $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
        $g.DrawPath($pen, $path)
        $pen.Dispose()

        # Inner 3D Gradient
        $y1 = [int]$rect.Top
        $y2 = [int]$rect.Bottom
        $gp1 = New-Object System.Drawing.Point 0, $y1
        $gp2 = New-Object System.Drawing.Point 0, $y2
        $textBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $gp1, $gp2, $gradColor1, $gradColor2
        $g.FillPath($textBrush, $path)
        $textBrush.Dispose()
        $path.Dispose()
    }

    # Line 1 (y: 65 to 195)
    $r1 = New-Object System.Drawing.RectangleF 0, 75, $src.Width, 125
    Draw-TextWithOutline $line1 82 $r1 ([System.Drawing.Color]::FromArgb(255, 255, 235, 120)) ([System.Drawing.Color]::FromArgb(255, 255, 140, 10)) ([System.Drawing.Color]::FromArgb(255, 14, 8, 4)) 16

    # Line 2 (y: 195 to 330)
    $r2 = New-Object System.Drawing.RectangleF 0, 195, $src.Width, 130
    Draw-TextWithOutline $line2 82 $r2 ([System.Drawing.Color]::FromArgb(255, 255, 245, 140)) ([System.Drawing.Color]::FromArgb(255, 255, 150, 15)) ([System.Drawing.Color]::FromArgb(255, 14, 8, 4)) 16

    # Subline (y: 360 to 450)
    $rSub = New-Object System.Drawing.RectangleF 0, 360, $src.Width, 80
    $subC1 = [System.Drawing.Color]::FromArgb(255, 170, 255, 255)
    $subC2 = [System.Drawing.Color]::FromArgb(255, 0, 215, 255)
    if ($theme -eq "water") {
        $subC1 = [System.Drawing.Color]::FromArgb(255, 190, 255, 235)
        $subC2 = [System.Drawing.Color]::FromArgb(255, 40, 235, 195)
    }
    Draw-TextWithOutline $subline 34 $rSub $subC1 $subC2 ([System.Drawing.Color]::FromArgb(255, 4, 12, 28)) 10

    # Save PNG
    $bmp.Save($dstPath, [System.Drawing.Imaging.ImageFormat]::Png)

    $sf.Dispose()
    $fontFamily.Dispose()
    $g.Dispose()
    $bmp.Dispose()
    $src.Dispose()
    Write-Output "Successfully generated: $dstPath"
}

$S_CAP = [char]0x015E
$I_CAP = [char]0x0130
$C_CAP = [char]0x00C7
$O_CAP = [char]0x00D6
$U_CAP = [char]0x00DC

# 1. Boss Savaşları (from screenshot_6)
Create-TrScreenshot `
    "C:\Users\USER\Desktop\KIPKIRMATAS\PLAY_STORE_HAZIR\screenshot_6.png" `
    "C:\Users\USER\Desktop\KIPKIRMATAS\PLAY_STORE_HAZIR\tr_screenshot_1.png" `
    "DEV MEKA" `
    "BOSS SAVA${S_CAP}LARI!" `
    "ROBOT PATRONLARI ALT ET & KAOSU Y${O_CAP}NET!" `
    "fire"

# 2. Canlı Haftalık Lig (from screenshot_2)
Create-TrScreenshot `
    "C:\Users\USER\Desktop\KIPKIRMATAS\PLAY_STORE_HAZIR\screenshot_2.png" `
    "C:\Users\USER\Desktop\KIPKIRMATAS\PLAY_STORE_HAZIR\tr_screenshot_2.png" `
    "CANLI HAFTALIK" `
    "L${I_CAP}GDE YARI${S_CAP}!" `
    "Z${I_CAP}RVEYE ${C_CAP}IK & B${U_CAP}Y${U_CAP}K ${O_CAP}D${U_CAP}L${U_CAP} KAZAN!" `
    "default"

# 3. Kendi Akvaryumunu Yarat (from screenshot_3)
Create-TrScreenshot `
    "C:\Users\USER\Desktop\KIPKIRMATAS\PLAY_STORE_HAZIR\screenshot_3.png" `
    "C:\Users\USER\Desktop\KIPKIRMATAS\PLAY_STORE_HAZIR\tr_screenshot_3.png" `
    "KEND${I_CAP} CANLI" `
    "AKVARYUMUNU KUR!" `
    "23+ FARKLI BALIK VE AHTAPOT BESLE!" `
    "water"
