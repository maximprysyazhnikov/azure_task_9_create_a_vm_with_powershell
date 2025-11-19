param()

$ErrorActionPreference = 'Stop'

# ---------- Базові налаштування ----------
$location          = 'northeurope'
$resourceGroupName = 'mate-azure-task-9'

$vnetName          = 'vnet'
$subnetName        = 'default'
$addressPrefix     = '10.10.0.0/16'
$subnetPrefix      = '10.10.0.0/24'

$nsgName           = 'defaultnsg'

$publicIpName      = 'linuxboxpip'
# 👇 ЦЕ ПОТРІБНО ЗМІНИТИ НА ЩОСЬ УНІКАЛЬНЕ (тільки маленькі букви, цифри, '-')
$dnsLabelPrefix    = 'mate9-maxim'   # приклад: mate9-maxim-2025

$sshKeyName        = 'linuxboxsshkey'

$vmName            = 'matebox'
$vmSize            = 'Standard_B1s'
$imageAlias        = 'Ubuntu2204'    # friendly name образу

Write-Host "=== Creating resource group ==="
New-AzResourceGroup -Name $resourceGroupName -Location $location -Force | Out-Null

Write-Host "=== Creating Network Security Group '$nsgName' ==="
$null = New-AzNetworkSecurityGroup `
    -Name $nsgName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -ErrorAction SilentlyContinue

# ---------- VNet + Subnet ----------
Write-Host "=== Creating Virtual Network '$vnetName' with subnet '$subnetName' ==="
$subnetConfig = New-AzVirtualNetworkSubnetConfig `
    -Name $subnetName `
    -AddressPrefix $subnetPrefix

$null = New-AzVirtualNetwork `
    -Name $vnetName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -AddressPrefix $addressPrefix `
    -Subnet $subnetConfig `
    -ErrorAction SilentlyContinue

# ---------- Public IP ----------
Write-Host "=== Creating Public IP '$publicIpName' with DNS label '$dnsLabelPrefix' ==="
$null = New-AzPublicIpAddress `
    -Name $publicIpName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -AllocationMethod Dynamic `
    -DomainNameLabel $dnsLabelPrefix `
    -ErrorAction SilentlyContinue

# ---------- SSH Key Resource ----------
Write-Host "=== Creating SSH key resource '$sshKeyName' ==="

# Спробуємо знайти існуючий публічний ключ
$publicKeyPath = Join-Path $HOME ".ssh/id_ed25519.pub"
if (-not (Test-Path -Path $publicKeyPath)) {
    $publicKeyPath = Join-Path $HOME ".ssh/id_rsa.pub"
}

if (Test-Path -Path $publicKeyPath) {
    Write-Host "Using existing SSH public key from $publicKeyPath"
    $publicKey = Get-Content -Path $publicKeyPath -Raw

    $null = New-AzSshKey `
        -ResourceGroupName $resourceGroupName `
        -Name $sshKeyName `
        -PublicKey $publicKey `
        -ErrorAction SilentlyContinue
}
else {
    Write-Host "No existing SSH public key found. Generating new key pair with New-AzSshKey..."
    $null = New-AzSshKey `
        -ResourceGroupName $resourceGroupName `
        -Name $sshKeyName `
        -ErrorAction SilentlyContinue
}

# ---------- Credentials for VM local user ----------
Write-Host "=== Enter credentials for the local user on VM '$vmName' ==="
$credential = Get-Credential -Message "Enter username and password for VM $vmName"

# ---------- Create VM ----------
Write-Host "=== Creating VM '$vmName' ==="

New-AzVM `
    -Name $vmName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -Credential $credential `
    -VirtualNetworkName $vnetName `
    -SubnetName $subnetName `
    -PublicIpAddressName $publicIpName `
    -SecurityGroupName $nsgName `
    -Image $imageAlias `
    -Size $vmSize `
    -SshKeyName $sshKeyName `
    -OpenPorts 22,8080 `
    -Verbose

Write-Host "=== VM '$vmName' has been created successfully ==="
