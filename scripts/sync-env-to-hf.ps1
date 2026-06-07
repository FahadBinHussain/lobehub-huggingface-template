param(
    [Parameter(Mandatory = $true)]
    [string]$HfEmail,

    [Parameter(Mandatory = $true)]
    [string]$SpaceId,

    [Parameter(Mandatory = $true)]
    [string]$EnvFile
)

$ErrorActionPreference = 'Stop'

$hfHelper = 'C:\Users\Admin\Downloads\mainframe\hf-account.ps1'

if (-not (Test-Path -LiteralPath $hfHelper)) {
    throw "Missing HF account helper: $hfHelper"
}

if (-not (Test-Path -LiteralPath $EnvFile)) {
    throw "Env file not found: $EnvFile"
}

$secretKeys = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
@(
    'DATABASE_URL',
    'KEY_VAULTS_SECRET',
    'AUTH_SECRET',
    'JWKS_KEY',
    'AUTH_GOOGLE_ID',
    'AUTH_GOOGLE_SECRET',
    'OPENAI_API_KEY',
    'S3_ACCESS_KEY_ID',
    'S3_SECRET_ACCESS_KEY',
    'REDIS_URL',
    'REDIS_PASSWORD',
    'REDIS_USERNAME'
) | ForEach-Object { [void]$secretKeys.Add($_) }

$allowedKeys = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
@(
    'APP_URL',
    'INTERNAL_APP_URL',
    'DATABASE_DRIVER',
    'DATABASE_URL',
    'KEY_VAULTS_SECRET',
    'AUTH_SECRET',
    'JWKS_KEY',
    'AUTH_SSO_PROVIDERS',
    'AUTH_DISABLE_EMAIL_PASSWORD',
    'AUTH_GOOGLE_ID',
    'AUTH_GOOGLE_SECRET',
    'OPENAI_PROXY_URL',
    'OPENAI_API_KEY',
    'ENABLED_UPLOAD',
    'ENABLED_KNOWLEDGE_BASE',
    'S3_ENDPOINT',
    'S3_BUCKET',
    'S3_REGION',
    'S3_ENABLE_PATH_STYLE',
    'S3_SET_ACL',
    'S3_ACCESS_KEY_ID',
    'S3_SECRET_ACCESS_KEY',
    'REDIS_URL',
    'REDIS_PREFIX',
    'REDIS_TLS',
    'REDIS_USERNAME',
    'REDIS_PASSWORD'
) | ForEach-Object { [void]$allowedKeys.Add($_) }

$pairs = [ordered]@{}

foreach ($line in Get-Content -LiteralPath $EnvFile) {
    $trimmed = $line.Trim()
    if (-not $trimmed -or $trimmed.StartsWith('#')) {
        continue
    }

    $match = [regex]::Match($trimmed, '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$')
    if (-not $match.Success) {
        continue
    }

    $key = $match.Groups[1].Value
    $value = $match.Groups[2].Value.Trim()

    if (-not $allowedKeys.Contains($key)) {
        continue
    }

    if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
        $value = $value.Substring(1, $value.Length - 2)
    }

    if ([string]::IsNullOrWhiteSpace($value)) {
        continue
    }

    $pairs[$key] = $value
}

if ($pairs.Count -eq 0) {
    throw 'No supported non-empty env values found.'
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('lobehub-hf-env-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

$secretFile = Join-Path $tempRoot 'secrets.env'
$variableFile = Join-Path $tempRoot 'variables.env'

try {
    $secretLines = New-Object System.Collections.Generic.List[string]
    $variableLines = New-Object System.Collections.Generic.List[string]

    foreach ($entry in $pairs.GetEnumerator()) {
        $line = "$($entry.Key)=$($entry.Value)"
        if ($secretKeys.Contains($entry.Key)) {
            $secretLines.Add($line)
        } else {
            $variableLines.Add($line)
        }
    }

    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)

    if ($secretLines.Count -gt 0) {
        [System.IO.File]::WriteAllLines($secretFile, [string[]]$secretLines, $utf8NoBom)
        & $hfHelper run $HfEmail spaces secrets add $SpaceId --secrets-file $secretFile --format quiet | Out-Null
    }

    if ($variableLines.Count -gt 0) {
        [System.IO.File]::WriteAllLines($variableFile, [string[]]$variableLines, $utf8NoBom)
        & $hfHelper run $HfEmail spaces variables add $SpaceId --env-file $variableFile --format quiet | Out-Null
    }

    Write-Host "Synced $($secretLines.Count) secrets and $($variableLines.Count) variables to $SpaceId."
    Write-Host 'Synced keys:'
    $pairs.Keys | Sort-Object | ForEach-Object { Write-Host "  $_" }
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
