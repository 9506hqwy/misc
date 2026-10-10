<#
  .NOTES
  Discussions API Merge requests
  https://docs.gitlab.com/api/discussions/#merge-requests
#>

[CmdletBinding()]
Param (
    [Parameter(Mandatory=$true)]
    [System.Uri]
    $Url,

    [Parameter(Mandatory=$true)]
    [string]
    $ProjectPath,

    [Parameter(Mandatory=$true)]
    [string]
    $MergeRequestIid
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

function Get-ContentFromResponse($response) {
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        return ConvertFrom-Json $response.Content
    }

    $bytes = [System.Text.Encoding]::GetEncoding("ISO-8859-1").GetBytes($response.Content)
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    return ConvertFrom-Json $text
}

$requestHeader = @{}
if ($env:GITLAB_TOKEN -ne $null -and $env:GITLAB_TOKEN -ne "") {
    $requestHeader["Authorization"] = "Bearer ${env:GITLAB_TOKEN}"
}

$projectPathEncoded = [System.Uri]::EscapeDataString($ProjectPath)
$normalizeMRIid = $MergeRequestIid.TrimStart("!")

$discussions = @()

$response = Invoke-WebRequest -Uri "${Url}/api/v4/projects/${projectPathEncoded}/merge_requests/${normalizeMRIid}/discussions?per_page=100" -Headers $requestHeader -UseBasicParsing
$discussions += Get-ContentFromResponse($response)

$nextUrl = Get-NextUrl $response.Headers.Link
while ($nextUrl -ne $null) {
    $response = Invoke-WebRequest -Uri "${nextUrl}" -Headers $requestHeader -UseBasicParsing
    $discussions += Get-ContentFromResponse($response)

    $nextUrl = Get-NextUrl $response.Headers.Link
}

Write-Output $discussions
