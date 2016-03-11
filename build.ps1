Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Update-NuSpec {
    param(
        [string]$Path,
        [string]$Version,
        [string]$ReleaseNotes
    )

    $ns = @{ nuspec = 'http://schemas.microsoft.com/packaging/2015/06/nuspec.xsd' }
    $xml = [xml](Get-Content -LiteralPath $Path -Raw)
   
    $el = $xml | Select-Xml -XPath '/nuspec:package/nuspec:metadata/nuspec:version' -Namespace $ns
    $el.Node.InnerText = $Version

    $el = $xml | Select-Xml -XPath '/nuspec:package/nuspec:metadata/nuspec:releaseNotes' -Namespace $ns
    $el.Node.InnerText = $ReleaseNotes

    $xml.Save($Path)
}

function Get-Caddy {
    param(
        [string]$Arch
    )

    $features = [string]::Join(",", @("cors"; "git"; "hugo"; "ipfilter"; "jsonp"; "mailout"; "search"))
    $url = "https://caddyserver.com/download/build?os=windows&arch=$Arch&features=$features"
    $file = Join-Path (Split-Path $PSCommandPath) "tools/caddy-$Arch.zip"

    Write-Output "  URL: $url"
    Invoke-WebRequest -Uri $url -OutFile $file
    Write-Output "  MD5: $((Get-FileHash $file -Algorithm MD5).Hash.ToLower())"
}

function Get-CaddyReleaseNotes {
    param(
        [string]$Version
    )

    $resp = Invoke-WebRequest "https://api.github.com/repos/mholt/caddy/releases/tags/v$Version" | select -ExpandProperty Content | ConvertFrom-Json
    return $resp.body.Trim()
}

$resp = Invoke-WebRequest -Uri 'https://caddyserver.com/download'
if (-not($resp -match 'Version\s+(\d+\.\d+\.\d+)')) {
    throw 'Failed to find the version number.'
}
$version = $Matches[1]
Write-Output "Caddy Version: $version"

Write-Output "Downloading 32-bit..."
Get-Caddy 386
Write-Output "Downloading 64-bit..."
Get-Caddy amd64

Write-Output "Fetching release notes..."
$releaseNotes = Get-CaddyReleaseNotes $version

Write-Output "Updating the NuSpec...."
$nuspec = Join-Path (Split-Path $PSCommandPath) 'caddy.nuspec'
Update-NuSpec -Path $nuspec -Version $version -ReleaseNotes $releaseNotes

Write-Output "Packing..."
choco pack $nuspec