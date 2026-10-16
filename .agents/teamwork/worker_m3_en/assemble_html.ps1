$body = [System.IO.File]::ReadAllText(".agents/teamwork/worker_m3_en/studio_body.html")
$audio = [System.IO.File]::ReadAllText(".agents/teamwork/worker_m3_en/audio_assets.js")
$images = [System.IO.File]::ReadAllText(".agents/teamwork/worker_m3_en/image_assets.js")
$engine = [System.IO.File]::ReadAllText(".agents/teamwork/worker_m3_en/studio_engine.js")

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine($body)
[void]$sb.AppendLine("<script>")
[void]$sb.AppendLine($audio)
[void]$sb.AppendLine($images)
[void]$sb.AppendLine($engine)
[void]$sb.AppendLine("</script>")
[void]$sb.AppendLine("</body>")
[void]$sb.AppendLine("</html>")

$outputPath = [System.IO.Path]::GetFullPath("docs/kirmatas_ad_en.html")
[System.IO.File]::WriteAllText($outputPath, $sb.ToString(), [System.Text.Encoding]::UTF8)

$size = (Get-Item $outputPath).Length
Write-Host "Successfully generated docs/kirmatas_ad_en.html ($size bytes)!"
