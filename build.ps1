$latest = Invoke-WebRequest https://api.github.com/repos/mholt/caddy/releases/latest | select -ExpandProperty Content | ConvertFrom-Json
$version = $latest.tag_name.TrimStart('v').Trim()
$releaseNotes = $latest.body.Trim()

Write-Output "Latest Caddy version: $version"

$nuspecFile = Join-Path $PSScriptRoot 'caddy.nuspec'

$ns = @{ nuspec = 'http://schemas.microsoft.com/packaging/2015/06/nuspec.xsd' }
$versionEl = Select-Xml -LiteralPath $nuspecFile -XPath '/nuspec:package/nuspec:metadata/nuspec:version' -Namespace $ns
$versionEl.Node.InnerText = $version
$versionEl.Node.OwnerDocument.Save($nuspecFile)

$versionEl = Select-Xml -LiteralPath $nuspecFile -XPath '/nuspec:package/nuspec:metadata/nuspec:releaseNotes' -Namespace $ns
$versionEl.Node.InnerText = $releaseNotes
$versionEl.Node.OwnerDocument.Save($nuspecFile)

choco pack