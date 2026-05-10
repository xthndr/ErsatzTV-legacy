# apply-epg-override.ps1
# Run this from the root of your ErsatzTV-legacy repo:
#   cd C:\Users\jmaha\ErsatzTV-legacy
#   .\apply-epg-override.ps1

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
Write-Host "=== Applying EPG Override changes ==="
Write-Host ""

# 1. ErsatzTV.Core/Domain/Channel.cs
Write-Host "[1/8] Channel.cs (domain model)"
PatchFile `
    "ErsatzTV.Core\Domain\Channel.cs" `
    "    public bool ShowInEpg { get; set; }`n    public string WebEncodedName => WebUtility.UrlEncode(Name);`n}" `
    "    public bool ShowInEpg { get; set; }`n    public bool EpgOverrideEnabled { get; set; }`n    public string EpgOverrideTitle { get; set; }`n    public string WebEncodedName => WebUtility.UrlEncode(Name);`n}"

# 2. ErsatzTV.Application/Channels/ChannelViewModel.cs
Write-Host "[2/8] ChannelViewModel.cs"
PatchFile `
    "ErsatzTV.Application\Channels\ChannelViewModel.cs" `
    "    bool IsEnabled,`n    bool ShowInEpg)`n{" `
    "    bool IsEnabled,`n    bool ShowInEpg,`n    bool EpgOverrideEnabled,`n    string EpgOverrideTitle)`n{"

# 3. ErsatzTV.Application/Channels/Mapper.cs
Write-Host "[3/8] Mapper.cs"
PatchFile `
    "ErsatzTV.Application\Channels\Mapper.cs" `
    "            channel.IsEnabled,`n            channel.ShowInEpg);" `
    "            channel.IsEnabled,`n            channel.ShowInEpg,`n            channel.EpgOverrideEnabled,`n            channel.EpgOverrideTitle);"

# 4. ErsatzTV.Application/Channels/Commands/UpdateChannel.cs
Write-Host "[4/8] UpdateChannel.cs"
PatchFile `
    "ErsatzTV.Application\Channels\Commands\UpdateChannel.cs" `
    "    bool IsEnabled,`n    bool ShowInEpg) : IRequest<Either<BaseError, ChannelViewModel>>;" `
    "    bool IsEnabled,`n    bool ShowInEpg,`n    bool EpgOverrideEnabled,`n    string EpgOverrideTitle) : IRequest<Either<BaseError, ChannelViewModel>>;"

# 5. ErsatzTV.Application/Channels/Commands/UpdateChannelHandler.cs
Write-Host "[5/8] UpdateChannelHandler.cs"
PatchFile `
    "ErsatzTV.Application\Channels\Commands\UpdateChannelHandler.cs" `
    "        c.IsEnabled = update.IsEnabled;`n        c.ShowInEpg = update.IsEnabled && update.ShowInEpg;" `
    "        c.IsEnabled = update.IsEnabled;`n        c.ShowInEpg = update.IsEnabled && update.ShowInEpg;`n        c.EpgOverrideEnabled = update.EpgOverrideEnabled;`n        c.EpgOverrideTitle = update.EpgOverrideTitle;"

# 6. ErsatzTV.ViewModels/ChannelEditViewModel.cs
Write-Host "[6/8] ChannelEditViewModel.cs"

PatchFile `
    "ErsatzTV\ViewModels\ChannelEditViewModel.cs" `
    "    public bool IsEnabled { get; set; }`n    public bool ShowInEpg { get; set; }" `
    "    public bool IsEnabled { get; set; }`n    public bool ShowInEpg { get; set; }`n    public bool EpgOverrideEnabled { get; set; }`n    public string EpgOverrideTitle { get; set; }"

PatchFile `
    "ErsatzTV\ViewModels\ChannelEditViewModel.cs" `
    "            IsEnabled,`n            ShowInEpg);`n`n    public CreateChannel ToCreate()" `
    "            IsEnabled,`n            ShowInEpg,`n            EpgOverrideEnabled,`n            EpgOverrideTitle);`n`n    public CreateChannel ToCreate()"

PatchFile `
    "ErsatzTV\ViewModels\ChannelEditViewModel.cs" `
    "            IsEnabled,`n            ShowInEpg);" `
    "            IsEnabled,`n            ShowInEpg,`n            EpgOverrideEnabled,`n            EpgOverrideTitle);"

# 7. ErsatzTV/Pages/ChannelEditor.razor
Write-Host "[7/8] ChannelEditor.razor (UI)"

$showInEpgBlock = @'
<MudStack Row="true" Breakpoint="Breakpoint.SmAndDown" Class="form-field-stack gap-md-8 mb-5">
    <div class="d-flex">
        <MudText>Show In EPG</MudText>
    </div>
    <MudCheckBox @bind-Value="_model.ShowInEpg" For="@(() => _model.ShowInEpg)" Dense="true"/>
</MudStack>
'@

$showInEpgBlockNew = @'
<MudStack Row="true" Breakpoint="Breakpoint.SmAndDown" Class="form-field-stack gap-md-8 mb-5">
    <div class="d-flex">
        <MudText>Show In EPG</MudText>
    </div>
    <MudCheckBox @bind-Value="_model.ShowInEpg" For="@(() => _model.ShowInEpg)" Dense="true"/>
</MudStack>
<MudStack Row="true" Breakpoint="Breakpoint.SmAndDown" Class="form-field-stack gap-md-8 mb-5">
    <div class="d-flex">
        <MudText>EPG Override</MudText>
    </div>
    <MudCheckBox @bind-Value="_model.EpgOverrideEnabled" For="@(() => _model.EpgOverrideEnabled)" Dense="true" Label="Generate dummy 2-hour EPG blocks"/>
</MudStack>
@if (_model.EpgOverrideEnabled)
{
    <MudStack Row="true" Breakpoint="Breakpoint.SmAndDown" Class="form-field-stack gap-md-8 mb-5">
        <div class="d-flex">
            <MudText>EPG Override Title</MudText>
        </div>
        <MudTextField @bind-Value="_model.EpgOverrideTitle" For="@(() => _model.EpgOverrideTitle)" HelperText="This title repeats as 2-hour blocks in the guide"/>
    </MudStack>
}
'@

PatchFile "ErsatzTV\Pages\ChannelEditor.razor" $showInEpgBlock $showInEpgBlockNew

PatchFile `
    "ErsatzTV\Pages\ChannelEditor.razor" `
    "                        _model.IsEnabled = channelViewModel.IsEnabled;`n                        _model.ShowInEpg = channelViewModel.ShowInEpg;" `
    "                        _model.IsEnabled = channelViewModel.IsEnabled;`n                        _model.ShowInEpg = channelViewModel.ShowInEpg;`n                        _model.EpgOverrideEnabled = channelViewModel.EpgOverrideEnabled;`n                        _model.EpgOverrideTitle = channelViewModel.EpgOverrideTitle;"

# 8. RefreshChannelDataHandler.cs
Write-Host "[8/8] RefreshChannelDataHandler.cs (XMLTV generation)"

$afterHiddenCheck = @'
            if (hiddenCount > 0)
            {
                File.Delete(targetFile);
                return;
            }

            string movieTemplateFileName = GetMovieTemplateFileName();
'@

$afterHiddenCheckNew = @'
            if (hiddenCount > 0)
            {
                File.Delete(targetFile);
                return;
            }

            // Check for per-channel EPG override - write dummy 2-hour programme blocks
            Option<Channel> maybeEpgOverride = await dbContext.Channels
                .AsNoTracking()
                .SelectOneAsync(
                    c => c.Number,
                    c => c.Number == request.ChannelNumber && c.EpgOverrideEnabled,
                    cancellationToken);

            foreach (Channel epgOverrideChannel in maybeEpgOverride)
            {
                if (!string.IsNullOrWhiteSpace(epgOverrideChannel.EpgOverrideTitle))
                {
                    int overrideDays = await _configElementRepository
                        .GetValue<int>(ConfigElementKey.XmltvDaysToBuild, cancellationToken)
                        .IfNoneAsync(2);

                    await using RecyclableMemoryStream overrideMs = _recyclableMemoryStreamManager.GetStream();
                    await using XmlWriter overrideXml = XmlWriter.Create(
                        overrideMs,
                        new XmlWriterSettings { Async = true, ConformanceLevel = ConformanceLevel.Fragment });

                    string channelId = ChannelIdentifier.FromNumber(request.ChannelNumber);
                    string safeTitle = System.Security.SecurityElement.Escape(epgOverrideChannel.EpgOverrideTitle);
                    DateTimeOffset overrideFinish = DateTimeOffset.UtcNow.AddDays(overrideDays);
                    DateTimeOffset now = DateTimeOffset.UtcNow;

                    // Align to the most recent even 2-hour boundary in UTC
                    DateTimeOffset current = new DateTimeOffset(
                        now.Year, now.Month, now.Day,
                        (now.Hour / 2) * 2, 0, 0, TimeSpan.Zero);

                    while (current < overrideFinish)
                    {
                        DateTimeOffset next = current.AddHours(2);
                        string progStart = current.ToString("yyyyMMddHHmmss zzz", CultureInfo.InvariantCulture).Replace(":", string.Empty);
                        string progStop  = next.ToString("yyyyMMddHHmmss zzz", CultureInfo.InvariantCulture).Replace(":", string.Empty);

                        await overrideXml.WriteRawAsync(
                            $"<programme start=\"{progStart}\" stop=\"{progStop}\" channel=\"{channelId}\">" +
                            $"<title lang=\"en\">{safeTitle}</title>" +
                            "</programme>");

                        current = next;
                    }

                    await overrideXml.FlushAsync();
                    string overrideTempFile = Path.GetTempFileName();
                    await File.WriteAllBytesAsync(overrideTempFile, overrideMs.ToArray(), cancellationToken);
                    File.Move(overrideTempFile, targetFile, true);
                    return;
                }
            }

            string movieTemplateFileName = GetMovieTemplateFileName();
'@

PatchFile `
    "ErsatzTV.Application\Channels\Commands\RefreshChannelDataHandler.cs" `
    $afterHiddenCheck `
    $afterHiddenCheckNew

Write-Host ""
Write-Host "=== All code changes applied successfully! ==="
Write-Host ""
Write-Host "NEXT STEP - create the database migration:"
Write-Host ""
Write-Host "  dotnet ef migrations add AddChannelEpgOverride --project ErsatzTV.Infrastructure.Sqlite --startup-project ErsatzTV"
Write-Host ""
Write-Host "Then build the Docker image:"
Write-Host ""
Write-Host "  docker build -t ersatztv-custom:latest -f docker/Dockerfile --build-arg INFO_VERSION=custom-docker ."
Write-Host ""
