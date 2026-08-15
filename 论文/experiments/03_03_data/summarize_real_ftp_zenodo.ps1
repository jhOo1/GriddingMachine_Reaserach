param(
    [Parameter(Mandatory = $true)]
    [string]$RunDirectory,
    [int]$ExpectedRows = 24,
    [switch]$RequireAll
)

$ErrorActionPreference = 'Stop'
$rawPath = Join-Path $RunDirectory 'real_ftp_zenodo_raw.csv'
$rows = @(Import-Csv -LiteralPath $rawPath)

if ($rows.Count -ne $ExpectedRows) {
    throw "Expected $ExpectedRows rows, found $($rows.Count)"
}

$successCount = @($rows | Where-Object { $_.success -eq 'true' }).Count
if ($RequireAll -and $successCount -ne $rows.Count) {
    throw "Only $successCount/$($rows.Count) downloads passed verification"
}

function Get-Median([double[]]$Values) {
    $sorted = @($Values | Sort-Object)
    $middle = [math]::Floor($sorted.Count / 2)
    if ($sorted.Count % 2 -eq 1) {
        return $sorted[$middle]
    }
    return ($sorted[$middle - 1] + $sorted[$middle]) / 2
}

$summary = $rows | Group-Object tag, mirror | ForEach-Object {
    $elapsed = @($_.Group | ForEach-Object { [double]$_.elapsed_s })
    [PSCustomObject]@{
        tag = $_.Group[0].tag
        mirror = $_.Group[0].mirror
        repetitions = $_.Count
        successes = @($_.Group | Where-Object { $_.success -eq 'true' }).Count
        expected_size = $_.Group[0].expected_size
        median_elapsed_s = (Get-Median $elapsed).ToString('F6', [Globalization.CultureInfo]::InvariantCulture)
        min_elapsed_s = ($elapsed | Measure-Object -Minimum).Minimum.ToString('F6', [Globalization.CultureInfo]::InvariantCulture)
        max_elapsed_s = ($elapsed | Measure-Object -Maximum).Maximum.ToString('F6', [Globalization.CultureInfo]::InvariantCulture)
    }
}

$summaryPath = Join-Path $RunDirectory 'real_ftp_zenodo_summary.csv'
$summary | Export-Csv -LiteralPath $summaryPath -NoTypeInformation -Encoding UTF8
Write-Output "validated=$successCount/$($rows.Count) summary=$summaryPath"
