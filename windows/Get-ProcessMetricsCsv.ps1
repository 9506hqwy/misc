<#
  .NOTES
  logman
  https://learn.microsoft.com/ja-jp/windows-server/administration/windows-commands/logman

  typeperf
  https://learn.microsoft.com/ja-jp/windows-server/administration/windows-commands/typeperf
#>

[CmdletBinding()]
Param (
    [Parameter(Mandatory=$true)]
    [string]
    $ProcessName,

    [Parameter(Mandatory=$true)]
    [int]
    $Interval
)

Set-StrictMode -Version 'Latest'
$ErrorActionPreference = 'Stop'

$p = Get-Process -Name $ProcessName

$counterSet = Get-Counter -ListSet 'Process'

$counters = $counterSet.PathsWithInstances |? { $_.Contains("Process($ProcessName)") } | Sort-Object

Get-Counter -Counter $counters -SampleInterval $Interval -Continuous |% {
   $row = [ordered]@{}
   $row['(PDH-CSV 4.0)'] = $_.TimeStamp.ToString('MM/dd/yyy HH:mm:ss.fff')
   $_.CounterSamples |% {
       $row[$_.Path] = $_.CookedValue
   }
   $row
} | ConvertTo-Csv
