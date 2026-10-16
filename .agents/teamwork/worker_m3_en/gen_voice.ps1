Add-Type -AssemblyName System.Speech
$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$synth.SelectVoice("Microsoft Zira Desktop")

$scenes = @(
    @{
        id = "scene1"
        file = "docs/ad_assets/voice_en_scene1.wav"
        rate = 7
        text = "Drop an iron marble from space? 25,000 miles per hour at 5,000 degrees!"
    },
    @{
        id = "scene2"
        file = "docs/ad_assets/voice_en_scene2.wav"
        rate = 6
        text = "Impact crater? No! The Cosmic Paddle intercepts it with a thirty-fireball corner hit!"
    },
    @{
        id = "scene3"
        file = "docs/ad_assets/voice_en_scene3.wav"
        rate = 4
        text = "Screen-clearing Ultimate lightning, deep 3-card Roguelike perks, and a zen aquarium to unwind."
    },
    @{
        id = "scene4"
        file = "docs/ad_assets/voice_en_scene4.wav"
        rate = 5
        text = "Can you survive the Wave-10 Chaos Boss? Download Kirmatas free on Google Play today!"
    }
)

foreach ($sc in $scenes) {
    $synth.Rate = $sc.rate
    $outPath = [System.IO.Path]::GetFullPath($sc.file)
    $synth.SetOutputToWaveFile($outPath)
    $synth.Speak($sc.text)
    $synth.SetOutputToNull()
}

Get-ChildItem docs/ad_assets/voice_en_*.wav | ForEach-Object {
    $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
    $rate = [System.BitConverter]::ToInt32($bytes, 24)
    $channels = [System.BitConverter]::ToInt16($bytes, 22)
    $bits = [System.BitConverter]::ToInt16($bytes, 34)
    $dur = ($bytes.Length - 44) / ($rate * $channels * ($bits / 8))
    Write-Host "$($_.Name): $([Math]::Round($dur, 2))s"
}
