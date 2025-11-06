<#
  .NOTES
  List repositories for a user
  https://docs.github.com/ja/rest/repos/repos?apiVersion=2022-11-28#list-repositories-for-a-user

  List issues
  https://docs.github.com/ja/rest/issues/issues?apiVersion=2022-11-28#list-repository-issues
#>

[CmdletBinding()]
Param (
    [Parameter(Mandatory=$true)]
    [string]
    $Owner
)

Set-StrictMode -Version 'Latest'
$ErrorActionPreference = 'Stop'

function Get-NextUrl($link) {
    $links = $link.Split(",")
    foreach ($link in $links) {
        if ($link -match '<(.+)>; rel="next"') {
            return $Matches.1
        }
    }

    return $null
}

$requestHeader = @{
    "Accept"="application/vnd.github+json";
    "X-GitHub-Api-Version"="2022-11-28"
}

if ($env:GITHUB_TOKEN -ne $null -and $env:GITHUB_TOKEN -ne "") {
    $requestHeader["Authorization"] = "Bearer ${env:GITHUB_TOKEN}"
}

$repositories = @()

$response = Invoke-WebRequest -Uri "https://api.github.com/users/${Owner}/repos" -Headers $requestHeader
$body = ConvertFrom-Json $response.Content
$repositories += $body |% { $_.name }

$nextUrl = Get-NextUrl $response.Headers.Link
while ($nextUrl -ne $null) {
    $response = Invoke-WebRequest -Uri "${nextUrl}" -Headers $requestHeader
    $body = ConvertFrom-Json $response.Content
    $repositories += $body |% { $_.name }

    $nextUrl = Get-NextUrl $response.Headers.Link
}

$requests = @()

foreach ($repository in $repositories) {
    $response = Invoke-WebRequest -Uri "https://api.github.com/repos/${Owner}/${repository}/issues" -Headers $requestHeader
    $body = ConvertFrom-Json $response.Content
    $requests += $body
}

Write-Output $requests
