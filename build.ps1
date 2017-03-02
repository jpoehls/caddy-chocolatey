Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Get-CaddyFeatures {
    $resp = Invoke-WebRequest -Uri https://caddyserver.com/features.json
    $json = $resp.Content | ConvertFrom-Json
    return $json | Select-Object type, name, description, required, @{ Name="docsUrl"; Expression={
        if ($_.docs) {
            "https://caddyserver.com$($_.docs)"
        } else { $null }
    } } | Sort-Object type, name
}

function Get-CaddyDownloadUrl {
    param(
        [string]$Arch,
        [string[]]$Features
    )

    $featuresStr = [string]::Join(",", $Features)
    return "https://caddyserver.com/download/build?os=windows&arch=$Arch&features=$featuresStr"
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
        [string]$ReleaseNotes,
        [string]$Description
    )

    $ns = @{ nuspec = 'http://schemas.microsoft.com/packaging/2015/06/nuspec.xsd' }
    $xml = [xml](Get-Content -LiteralPath $Path -Raw)
   
    $el = $xml | Select-Xml -XPath '/nuspec:package/nuspec:metadata/nuspec:version' -Namespace $ns
    $el.Node.InnerText = $Version

    $el = $xml | Select-Xml -XPath '/nuspec:package/nuspec:metadata/nuspec:releaseNotes' -Namespace $ns
    $el.Node.InnerText = $ReleaseNotes

    $el = $xml | Select-Xml -XPath '/nuspec:package/nuspec:metadata/nuspec:description' -Namespace $ns
    $el.Node.InnerText = $Description

    $xml.Save($Path)
}

function Get-Caddy {
    param(
        [string]$Arch,
        [string[]]$Features
    )

    $relFile = Get-CaddyDownloadTarget $Arch -Relative
    $file = Get-CaddyDownloadTarget $Arch
    $url = Get-CaddyDownloadUrl -Arch $Arch -Features $Features

    Write-Output "   URL: $url"
    Invoke-WebRequest -Uri $url -OutFile $file
    Write-Output "  FILE: $relFile"
    Write-Output "   MD5: $((Get-FileHash $file -Algorithm MD5).Hash.ToLower())"
}

function Get-CaddyReleaseNotes {
    param(
        [string]$Version
    )

    $resp = Invoke-WebRequest "https://api.github.com/repos/mholt/caddy/releases/tags/v$Version" | Select-Object -ExpandProperty Content | ConvertFrom-Json
    return $resp.body.Trim()
}

function New-VerificationFile {
    param(
        [string]$CaddyVersion,
        [string[]]$Features
    )
    
    $txt = @"
VERIFICATION.TXT is intended to assist the Chocolatey moderators and community
in verifying that this package's contents are trustworthy.

The following package files can be verified by comparing a hash of their content
to hash of the file available at the corresponding download URL.

These download URLs are what we assert to be the trusted source for those files.

    $(Get-CaddyDownloadTarget 'amd64' -Relative): $(Get-CaddyDownloadUrl -Arch 'amd64' -Features $Features)
    $(Get-CaddyDownloadTarget '386' -Relative): $(Get-CaddyDownloadUrl -Arch '386' -Features $Features)

CAVEAT!

Caddy's download server only serves the most recent release. As such, the URLs
above always point to the most recent Caddy release which may not match this
package version.

This package is built for Caddy version: $CaddyVersion.
"@

    $outfile = "tools/verification.txt"
    $txt | Out-File $outfile -Encoding utf8
}

function Get-FeatureDescriptionLineItem {
    param(
        $Feature
    )

    $line = ""
    if ($_.docsUrl) {
        $line = "$line`n- [$($_.name)]($($_.docsUrl))"
    } else {
        $line = "$line`n- $($_.name)"
    }
    if ($_.description) {
        $line = "$line - $($_.description)"
    }
    return $line
}

$resp = Invoke-WebRequest -Uri 'https://caddyserver.com/download'
if (-not($resp -match 'Version\s+(\d+\.\d+\.\d+)')) {
    throw 'Failed to find the version number.'
}
$version = $Matches[1]
Write-Output "Caddy Version: $version"

Write-Output "Fetching features..."
$features = Get-CaddyFeatures
[string[]]$optionalFeatures = $features | ? { -not($_.required) } | Select-Object -ExpandProperty name | sort

Write-Output "Downloading 32-bit..."
Get-Caddy '386' $optionalFeatures
Write-Output "Downloading 64-bit..."
Get-Caddy 'amd64' $optionalFeatures

Write-Output "Writing verification.txt..."
New-VerificationFile -CaddyVersion $version -Features $optionalFeatures

Write-Output "Fetching release notes..."
$releaseNotes = Get-CaddyReleaseNotes $version

Write-Output "Updating the NuSpec...."

$desc =
@"
Caddy is a lightweight, general-purpose web server for Windows, Mac, Linux, BSD and Android. It is a capable alternative to other popular and easy to use web servers. ([@caddyserver](https://twitter.com/caddyserver) on Twitter)

The most notable features are HTTP/2, [Let's Encrypt](https://letsencrypt.org/) support, Virtual Hosts, TLS + SNI, and easy configuration with a [Caddyfile](https://caddyserver.com/docs/caddyfile). In development, you usually put one Caddyfile with each site. In production, Caddy serves HTTPS by default and manages all cryptographic assets for you.

[User Guide](https://caddyserver.com/docs)

**Server Types**

"@
$features | ? { $_.type -eq "server" } | sort name | % { $desc = "$desc$(Get-FeatureDescriptionLineItem $_)" }
$desc = "$desc`n`n**Directives/Middleware**`n"
$features | ? { $_.type -eq "directive" } | sort name | % { $desc = "$desc$(Get-FeatureDescriptionLineItem $_)" }
$desc = "$desc`n`n**DNS Providers**`n"
$features | ? { $_.type -eq "dns_provider" } | sort name | % { $desc = "$desc$(Get-FeatureDescriptionLineItem $_)" }

$nuspec = Join-Path (Split-Path $PSCommandPath) 'caddy.nuspec'
Update-NuSpec -Path $nuspec -Version $version -ReleaseNotes $releaseNotes -Description $desc

Write-Output "Packing..."
choco pack $nuspec

Write-Output "Done. Run this to publish:`n`n    choco push caddy.$version.nupkg`n"