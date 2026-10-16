$files = @{
    "sfx_cam_kirilma" = "assets/audio/cam_kirilma.mp3"
    "sfx_glass_shatter" = "assets/audio/glass_shatter.mp3"
    "sfx_custom_laser" = "assets/audio/custom_laser.wav"
    "sfx_custom_explosion" = "assets/audio/custom_explosion.wav"
    "sfx_custom_bounce" = "assets/audio/custom_bounce.wav"
    "voice_scene1" = "docs/ad_assets/voice_en_scene1.wav"
    "voice_scene2" = "docs/ad_assets/voice_en_scene2.wav"
    "voice_scene3" = "docs/ad_assets/voice_en_scene3.wav"
    "voice_scene4" = "docs/ad_assets/voice_en_scene4.wav"
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("// Auto-generated base64 audio assets for offline portability")
[void]$sb.AppendLine("const AUDIO_ASSETS = {")

foreach ($key in $files.Keys) {
    $path = $files[$key]
    $ext = [System.IO.Path]::GetExtension($path).TrimStart('.').ToLower()
    $mime = if ($ext -eq "mp3") { "audio/mp3" } else { "audio/wav" }
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $b64 = [Convert]::ToBase64String($bytes)
    [void]$sb.AppendLine("  '$key': 'data:$mime;base64,$b64',")
    Write-Host "$key : $($bytes.Length) bytes -> $($b64.Length) chars"
}

[void]$sb.AppendLine("};")

[System.IO.File]::WriteAllText(".agents/teamwork/worker_m3_en/audio_assets.js", $sb.ToString())
Write-Host "Generated audio_assets.js successfully!"
