$installDir = Split-Path -parent $MyInvocation.MyCommand.Definition
 
Install-ChocolateyZipPackage `
    -packageName 'caddy' `
    -url 'https://caddyserver.com/download/build?os=windows&arch=386&features=cors%2Cgit%2Chugo%2Cipfilter%2Cjsonp%2Cmailout%2Csearch' `
    -url64bit 'https://caddyserver.com/download/build?os=windows&arch=amd64&features=cors%2Cgit%2Chugo%2Cipfilter%2Cjsonp%2Cmailout%2Csearch' `
    -unzipLocation $installDir