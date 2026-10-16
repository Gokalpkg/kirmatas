$images = @{
    "img_action" = "docs/ad_assets/game_canvas_action.png"
    "img_perks" = "docs/ad_assets/chaos_perks.png"
    "img_synergies" = "docs/ad_assets/shop_synergies.png"
    "img_aquarium" = "docs/ad_assets/aquarium_view.png"
    "img_league" = "docs/ad_assets/tournament_league.png"
    "img_boss" = "docs/ad_assets/chaos_boss.png"
    "img_kaunos" = "assets/images/kaunos_games.png"
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("// Auto-generated base64 image assets for origin-clean canvas capture")
[void]$sb.AppendLine("const IMAGE_ASSETS = {")

foreach ($key in $images.Keys) {
    $path = $images[$key]
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $b64 = [Convert]::ToBase64String($bytes)
    [void]$sb.AppendLine("  '$key': 'data:image/png;base64,$b64',")
    Write-Host "$key : $($bytes.Length) bytes -> $($b64.Length) chars"
}

[void]$sb.AppendLine("};")

[System.IO.File]::WriteAllText(".agents/teamwork/worker_m3_en/image_assets.js", $sb.ToString())
Write-Host "Generated image_assets.js successfully!"
