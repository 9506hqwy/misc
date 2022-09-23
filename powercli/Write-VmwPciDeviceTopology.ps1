<#
  .NOTES
  Mapping PCI slot numbers to guest-visible PCI bus topology (2047927)
  https://kb.vmware.com/s/article/2047927
#>

[CmdletBinding()]
Param (
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    [object]
    $Vm
)

Set-StrictMode -Version 'Latest'
$ErrorActionPreference = 'Stop'

$extraConfigs = Get-AdvancedSetting -Entity $Vm

$pciDevices = @($extraConfigs |? { $_.Name -like '*.pciSlotNumber' })

$pciBridges = $pciDevices |? { $_.Name -like 'pciBridge*' } | Sort-Object -Property 'Value'
$pciDevices = $pciDevices |? { $pciBridges -notcontains $_ } | Sort-Object -Property 'Value'

$pciNodes = @()

Function Find-ParentNode {
    Param($Func, $Bus)

    $brNumber = $Bus - 1
    $bridge = $pciBridges |? { $_.Name -eq "pciBridge${brNumber}.pciSlotNumber" }
    $parentNodes = @($pciNodes |? { $_.Self.Value -eq $bridge.Value })
    $parentNodes |? { $_.Function -eq $Func }
}

foreach ($bridge in $pciBridges) {
    $vdev = $bridge.Name.Replace('pciSlotNumber', 'virtualDev')
    $isPcieRootPort = $null -ne ($extraConfigs |? { $_.Name -eq "$vdev" -and $_.Value -eq 'pcieRootPort' })

    $bus = ($bridge.Value -shr 5) -band 31
    $func = ($bridge.Value -shr 10) -band 7

    if (0 -ne $bus) {
        $parentNode = Find-ParentNode -Func $func -Bus $bus
        $parentNode.Children += @{
            Self=$bridge;
            Children=@();
            Primary=0;
            Secondary=0
            Subordinary=0;
            Function=0;
        }
    } else {
        $pciNodes += @{
            Self=$bridge;
            Children=@();
            Primary=0;
            Secondary=0
            Subordinary=0;
            Function=0;
        }

        if ($isPcieRootPort) {
            $pciePort = $bridge.Name.Replace('pciSlotNumber', 'functions')
            $pciePortNum = ($extraConfigs |? { $_.Name -eq "$pciePort" }).Value
            for ($i = 1; $i -lt $pciePortNum; $i++) {
                $pciNodes += @{
                    Self=$bridge;
                    Children=@();
                    Primary=0;
                    Secondary=0
                    Subordinary=0;
                    Function=$i;
                }
            }
        }
    }
}

Function Scan-Node {
    Param($Node)

    foreach ($child in $Node.Children) {
        $child.Primary = $Node.Secondary
        $child.Secondary = $Node.Subordinary + 1
        $child.Subordinary = $child.Secondary

        Scan-Node -Node $child

        $Node.Subordinary = $child.Subordinary
    }
}

$root = @{
    Children=$pciNodes;
    Primary=-1;
    Secondary=0
    Subordinary=0;
}

Scan-Node -Node $root

foreach ($device in $pciDevices) {
    $bus = ($device.Value -shr 5) -band 31
    $func = ($device.Value -shr 10) -band 7

    if (0 -ne $bus) {
        $bridgeNode = Find-ParentNode -Func $func -Bus $bus
        $bridgeNode.Children += @{
            Self=$device;
            Children=@();
            Primary=$bridgeNode.Secondary;
            Secondary=0
            Subordinary=0;
            Function=0;
        }
    } else {
        $pciNodes += @{
            Self=$device;
            Children=@();
            Primary=0;
            Secondary=0
            Subordinary=0;
            Function=0;
        }
    }
}

$devices = $Vm.ExtensionData.Config.Hardware.Device

Function Write-Slot {
    Param($Node, $Indent)

    $name = ''
    $device = $devices |? { $null -ne $_.SlotInfo -and $Node.Self.Value -eq $_.SlotInfo.PciSlotNumber }
    if ($null -ne $device) {
        $name = $device.DeviceInfo.Label
        if ($device -is [VMware.Vim.VirtualEthernetCard]) {
            $macAddress = $device.MacAddress
            $name += " (${macAddress})"
        }
    }

    $xbus = $node.Primary.ToString('x2')
    $xdev = ($node.Self.Value -band 31).ToString('x2')
    $xfunc = $node.Function.ToString('x1')
    $prefix = '  ' * $Indent
    Write-Output "${prefix}${xbus}:${xdev}.${xfunc} $name"

    if ($null -ne $device -and $device -is [VMware.Vim.VirtualController]) {
        foreach ($child in @($devices |? { $_.ControllerKey -eq $device.Key } | Sort-Object -Property 'UnitNumber')) {
            $busNumber = $device.BusNumber
            $unitNumber = $child.UnitNumber
            $childName = $child.DeviceInfo.Label
            Write-Output "${prefix}        ${busNumber}:${unitNumber} ${childName}"
        }
    }

    foreach ($child in $node.Children) {
        Write-Slot -Node $child -Indent ($Indent + 1)
    }
}

foreach ($node in $pciNodes) {
    Write-Slot -Node $node -Indent 0
}
