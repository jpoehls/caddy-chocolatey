$installDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$zipFile = if (Get-ProcessorBits 32) {
    Join-Path $installDir "caddy-386.zip"
} else {
    Join-Path $installDir "caddy-amd64.zip"
}

Get-ChocolateyUnzip $zipFile $installDir