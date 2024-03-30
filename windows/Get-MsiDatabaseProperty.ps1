<#
  .NOTES
  Installer object
  https://learn.microsoft.com/en-US/windows/win32/msi/installer-object
#>

[CmdletBinding()]
Param (
    [Parameter(Mandatory=$true)]
    [System.IO.FileInfo]
    $File
)

Set-StrictMode -Version 'Latest'
$ErrorActionPreference = 'Stop'

$type = [Type]::GetTypeFromProgID('WindowsInstaller.Installer')
$installer = [Activator]::CreateInstance($type)

$database = $installer.OpenDatabase($File.FullName, 0);

# https://learn.microsoft.com/en-US/windows/win32/msi/property-table
$sql = 'SELECT Property, Value From Property'

$view = $database.OpenView($sql);
$view.Execute($null)

$properties = @{}

$record = $view.Fetch()
while ($null -ne $record) {
    $property = $record.StringData(1)
    $value = $record.StringData(2)
    $properties.add($property, $value)

    $record = $view.Fetch()
}

$view.Close()

Write-Output $properties
