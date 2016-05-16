Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-CaddyDownloadUrl {
    param(
        [string]$Arch
    )
    
    $features = [string]::Join(",", @(
        "cors";
        "git";
        "hugo";
        "ipfilter";
        "jsonp";
        "jwt";
        "mailout";
        "prometheus";
        "realip";
        "search";
        "upload"))
    return "https://caddyserver.com/download/build?os=windows&arch=$Arch&features=$features"
}

function Get-CaddyDownloadTarget {
    param(
        [string]$Arch,
        [switch]$Relative
    )
    
    $rel = "tools/caddy-$Arch.zip"
    if ($Relative) {
        return $rel
    }
    else {
        return Join-Path (Split-Path $PSCommandPath) $rel 
    }
}

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

    $relFile = Get-CaddyDownloadTarget $Arch -Relative
    $file = Get-CaddyDownloadTarget $Arch
    $url = Get-CaddyDownloadUrl $Arch

    Write-Output "   URL: $url"
    Invoke-WebRequest -Uri $url -OutFile $file
    Write-Output "  FILE: $relFile"
    Write-Output "   MD5: $((Get-FileHash $file -Algorithm MD5).Hash.ToLower())"
}

function Get-CaddyReleaseNotes {
    param(
        [string]$Version
    )

    $resp = Invoke-WebRequest "https://api.github.com/repos/mholt/caddy/releases/tags/v$Version" | select -ExpandProperty Content | ConvertFrom-Json
    return $resp.body.Trim()
}

function New-VerificationFile {
    param(
        [string]$CaddyVersion
    )
    
    $txt = @"
VERIFICATION.TXT is intended to assist the Chocolatey moderators and community
in verifying that this package's contents are trustworthy.

The following package files can be verified by comparing a hash of their content
to hash of the file available at the corresponding download URL.

These download URLs are what we assert to be the trusted source for those files.

    $(Get-CaddyDownloadTarget 'amd64' -Relative): $(Get-CaddyDownloadUrl 'amd64')
    $(Get-CaddyDownloadTarget '386' -Relative): $(Get-CaddyDownloadUrl '386')

CAVEAT!

Caddy's download server only serves the most recent release. As such, the URLs
above always point to the most recent Caddy release which may not match this
package version.

This package is built for Caddy version: $CaddyVersion.
"@

    $outfile = "tools/verification.txt"
    $txt | Out-File $outfile -Encoding utf8
}

$resp = Invoke-WebRequest -Uri 'https://caddyserver.com/download'
if (-not($resp -match 'Version\s+(\d+\.\d+\.\d+)')) {
    throw 'Failed to find the version number.'
}
$version = $Matches[1]
Write-Output "Caddy Version: $version"

Write-Output "Downloading 32-bit..."
Get-Caddy '386'
Write-Output "Downloading 64-bit..."
Get-Caddy 'amd64'

Write-Output "Writing verification.txt..."
New-VerificationFile -CaddyVersion $version

Write-Output "Fetching release notes..."
$releaseNotes = Get-CaddyReleaseNotes $version

Write-Output "Updating the NuSpec...."
$nuspec = Join-Path (Split-Path $PSCommandPath) 'caddy.nuspec'
Update-NuSpec -Path $nuspec -Version $version -ReleaseNotes $releaseNotes

Write-Output "Packing..."
choco pack $nuspec

Write-Output "Done. Run this to publish:`n`n    choco push caddy.$version.nupkg`n"