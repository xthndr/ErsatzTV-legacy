# fix-create-channel.ps1
# Run from repo root: .\fix-create-channel.ps1

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

function PatchFile($relativePath, $oldText, $newText) {
    $full = Join-Path $root $relativePath
    $raw = Get-Content $full -Raw
    $content  = $raw.Replace("`r`n", "`n")
    $oldNorm  = $oldText.Replace("`r`n", "`n")
    $newNorm  = $newText.Replace("`r`n", "`n")
    if (-not $content.Contains($oldNorm)) {
        Write-Error "PATCH FAILED: Could not find target text in $relativePath"
        exit 1
    }
    $result = $content.Replace($oldNorm, $newNorm)
    if ($raw.Contains("`r`n")) { $result = $result.Replace("`n", "`r`n") }
    Set-Content $full $result -NoNewline
    Write-Host "  Patched: $relativePath"
}

Write-Host ""
Write-Host "=== Patching CreateChannel files ==="
Write-Host ""

Write-Host "[1/2] CreateChannel.cs"
PatchFile `
    "ErsatzTV.Application\Channels\Commands\CreateChannel.cs" `
    "    bool IsEnabled,`n    bool ShowInEpg) : IRequest<Either<BaseError, CreateChannelResult>>;" `
    "    bool IsEnabled,`n    bool ShowInEpg,`n    bool EpgOverrideEnabled,`n    string EpgOverrideTitle) : IRequest<Either<BaseError, CreateChannelResult>>;"

Write-Host "[2/2] CreateChannelHandler.cs"
PatchFile `
    "ErsatzTV.Application\Channels\Commands\CreateChannelHandler.cs" `
    "                IsEnabled = request.IsEnabled,`n                ShowInEpg = request.IsEnabled && request.ShowInEpg" `
    "                IsEnabled = request.IsEnabled,`n                ShowInEpg = request.IsEnabled && request.ShowInEpg,`n                EpgOverrideEnabled = request.EpgOverrideEnabled,`n                EpgOverrideTitle = request.EpgOverrideTitle"

Write-Host ""
Write-Host "=== Done! ==="
Write-Host ""
