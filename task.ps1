$location = "uksouth"
$resourceGroupName = "mate-azure-task-10"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$sshKeyName = "linuxboxsshkey"

# Read SSH key
$sshKeyPath = Join-Path $HOME ".ssh/id_ed25519.pub"
if (-not (Test-Path $sshKeyPath)) {
    Write-Error "SSH public key not found at $sshKeyPath. Please generate or specify a valid key before running this script."
    exit 1
}
$sshKeyPublicKey = (Get-Content -Raw $sshKeyPath).Trim()

$vmImage = "Ubuntu2204"
$vmSize = "Standard_B1s"

Write-Host "Creating a resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location

Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH  -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP  -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow
New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

$subnet = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix
New-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix $vnetAddressPrefix -Subnet $subnet

New-AzSshKey -Name $sshKeyName -ResourceGroupName $resourceGroupName -PublicKey $sshKeyPublicKey

# Two VMs in different availability zones
$zones = @('1','2')
$vmNames = @("matebox1", "matebox2")

if ($zones.Length -ne $vmNames.Length) {
    Write-Error "Zones and VM names arrays must be the same length."
    exit 1
}

for ($i = 0; $i -lt $zones.Length; $i++) {
    Write-Host "Creating VM $($vmNames[$i]) in Zone $($zones[$i]) ..."

    New-AzVm `
        -ResourceGroupName $resourceGroupName `
        -Name $vmNames[$i] `
        -Location $location `
        -Zone $zones[$i] `
        -Image $vmImage `
        -Size $vmSize `
        -SubnetName $subnetName `
        -VirtualNetworkName $virtualNetworkName `
        -SecurityGroupName $networkSecurityGroupName `
        -SshKeyName $sshKeyName
}