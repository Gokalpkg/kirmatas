Add-Type -AssemblyName System.Drawing

$sourcePath = "C:\Users\USER\.gemini\antigravity\brain\2d80aa4e-ef16-4ceb-bb24-fd4bb5d03659\game_icon_512_enhanced_impact.png"
$srcImg = [System.Drawing.Image]::FromFile($sourcePath)

function Resize-Icon($targetPath, $w, $h) {
    $destBmp = New-Object System.Drawing.Bitmap($w, $h)
    $g = [System.Drawing.Graphics]::FromImage($destBmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
    $g.DrawImage($srcImg, 0, 0, $w, $h)
    $g.Dispose()
    
    $dir = [System.IO.Path]::GetDirectoryName($targetPath)
    if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    
    $destBmp.Save($targetPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $destBmp.Dispose()
    Write-Host ("Generated: " + $targetPath + " (" + $w + "x" + $h + ")")
}

Resize-Icon "android\app\src\main\res\mipmap-mdpi\ic_launcher.png" 48 48
Resize-Icon "android\app\src\main\res\mipmap-hdpi\ic_launcher.png" 72 72
Resize-Icon "android\app\src\main\res\mipmap-xhdpi\ic_launcher.png" 96 96
Resize-Icon "android\app\src\main\res\mipmap-xxhdpi\ic_launcher.png" 144 144
Resize-Icon "android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png" 192 192
Resize-Icon "android\app\src\main\res\ic_launcher-playstore.png" 512 512

$srcImg.Dispose()
Write-Host "All mipmap icons updated successfully!"
