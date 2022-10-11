<#
  .NOTES
  Unified Extensible Firmware Interface (UEFI) Specification 2.10
  32.4.1 Signature Database
  https://uefi.org/specifications
#>

[CmdletBinding()]
Param ()

$CERT_X509_UUID = [Guid]"a5c059a1-94e4-4aa7-87b5-ab155c2bf072"

Set-StrictMode -Version 'Latest'
$ErrorActionPreference = 'Stop'

$value = (Get-SecureBootUEFI -Name 'db').Bytes
$listStartIndex = 0

$certs = @()
while ($listStartIndex -lt $value.Length) {
    $sigType = [Guid][Byte[]]$value[$listStartIndex..($listStartIndex+15)]
    $listSize = [BitConverter]::ToUInt32($value, $listStartIndex + 16)
    $headerSize = [BitConverter]::ToUInt32($value, $listStartIndex + 20)
    $sigSize = [BitConverter]::ToUInt32($value, $listStartIndex + 24)

    # $headerSize=0 if sig is x509.
    # $sigSize=16+cert length if sig is x509.
    $sigStartIndex = $listStartIndex + 28
    $sigEndIndex = $listStartIndex + $listSize - 1

    if ($CERT_X509_UUID -eq $sigType) {
        while ($sigStartIndex -lt $sigEndIndex) {
            $sigOwner = [Guid][Byte[]]$value[$sigStartIndex..($sigStartIndex + 15)]

            $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
            $cert.Import([Byte[]]$value[($sigStartIndex + 16)..($sigStartIndex + $sigSize - 1)])
            $certs += $cert

            $sigStartIndex = $sigStartIndex + $sigSize

            # only one cert.
        }
    }

    $listStartIndex = $sigEndIndex + 1
}

Write-Output $certs
