# fix-shuffle-boundary.ps1
# Improves shuffle boundary protection to prevent recently-played items
# from appearing too soon at the start of the next shuffle pass.
# Run from repo root: .\fix-shuffle-boundary.ps1

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
Write-Host "=== Patching ShuffledMediaCollectionEnumerator ==="
Write-Host ""

$oldReshuffle = @'
        if ((State.Index + 1) % _mediaItemCount == 0)
        {
            Option<MediaItem> tail = Current;

            State.Index = 0;
            do
            {
                State.Seed = _random.Next();
                _random = new CloneableRandom(State.Seed);
                _shuffled = Shuffle(_mediaItems, _random);
            } while (!_cancellationToken.IsCancellationRequested && _mediaItems.Count > 1 &&
                     _shuffled.Count > 0 && Current.Map(x => x.Id) == tail.Map(x => x.Id));
        }
'@

$newReshuffle = @'
        if ((State.Index + 1) % _mediaItemCount == 0)
        {
            // Collect the last N recently-played items to avoid at the start of the next shuffle.
            // Protection scales with collection size: ~20% lookback, capped at 20, minimum 3.
            // Examples: 20 items = 4, 50 items = 10, 100 items = 20, 200+ items = 20.
            int lookback = Math.Max(3, Math.Min(20, _shuffled.Count / 5));
            var recentIds = new HashSet<int>();
            for (int t = Math.Max(0, _shuffled.Count - lookback); t < _shuffled.Count; t++)
            {
                recentIds.Add(_shuffled[t].Id);
            }

            State.Index = 0;
            int attempts = 0;
            do
            {
                State.Seed = _random.Next();
                _random = new CloneableRandom(State.Seed);
                _shuffled = Shuffle(_mediaItems, _random);
                attempts++;
            } while (!_cancellationToken.IsCancellationRequested && _mediaItems.Count > lookback &&
                     _shuffled.Count > 0 && attempts < 20 &&
                     Current.Map(x => x.Id).Map(id => recentIds.Contains(id)).IfNone(false));
        }
'@

PatchFile "ErsatzTV.Core\Scheduling\ShuffledMediaCollectionEnumerator.cs" $oldReshuffle $newReshuffle

Write-Host ""
Write-Host "=== Done! ==="
Write-Host ""
Write-Host "Now commit, rebuild Docker image, and redeploy."
Write-Host ""
