#region Azure MatrixMind Parameters

<#
Numbering resources:
001 - 099 = Management
100 - 699 = Production
700 - 799 = Development
800 - 899 = Test
900 - 999 = UAT (Acceptance)

Locations:
20 = West Europe
40 = North Europe
#>

#PowerShell Settings
$VerbosePreference = 'Continue'

#Location settings
$DefaultLocation = 'West Europe'
$DefaultEnvironment = 'Production'

#Automation Account settings (goes into management RG)
$AutomationAccountResourceGroup = 'rg20m001'
$AutomationAccountName = 'aa20m001'
$AutomationAccountPlan = 'Free'

#Network settings
$DeployNetwork = $False
$NetworkResourceGroupName = 'rg20p100'
$NetworkResourceGroupTag = @{Name = 'Environment' ; value = $DefaultEnvironment}
$vNetName = 'vn20p001'
$vNetPrefix = '192.168.0.0/16'
$vnetPerimeterSubnetName = 'sn20vnp001pm01'
$vnetPerimeterPrefix = '192.168.1.0/24'
$vnetAppSubnetName = 'sn20vnp001app01'
$vnetAppPrefix = '192.168.2.0/24'
$vnetBackEndSubnetName = 'sn20vnp001be01'
$vnetBackEndPrefix = '192.168.3.0/24'
$vnetGatewaySubnetPrefix = '192.168.0.0/28'

#Site to Site VPN Settings
$DeployVPN = $False
$VPNResourceGroupName = $NetworkResourceGroupName
$VPNResourceGroupTag = @{Name = 'Environment' ; value = $DefaultEnvironment}
$VpnType = 'RouteBased'
$VpnLocalGatewayName = 'lgw20p001'
$VpnLocalGatewayIpAddress = '83.82.1.1'
$VpnLocalAddressPrefix = '10.0.0.0/8'
$VpnGatewayPublicIPName = 'gw20p001ip'
$VpnGatewayName = 'gw20p001'
$VpnConnectionName = 'gw001lgw001'
$VpnSharedKey = 1234

#Storage account settings
$DeployStorage = $False
$StorageAccountProdName = 'sagrs20p100'
$StorageProdResourceGroup = 'rg20p101'
$StorageAccountProdType = 'Standard_LRS'

$StorageAccountNonProdName = 'salrs20dta700'
$StorageNonProdResourceGroup = 'rg20dta700'
$StorageAccountNonProdType = 'Standard_LRS'

#Domain Controller Settings
$DeployActiveDirectory = $False
$DomainResourceGroup = 'rg20p104'
$DomainStorageAccountName = $StorageAccountProdName
$Domainlocation = $DefaultLocation
$DomainvirtualNetworkName = $vNetName
$DomainadSubnetName = $vnetAppSubnetName
$DomainadPDCVMName = 'sw20addc100'
$DomainadPDCNicName = "$DomainadPDCVMName-nic"
$DomainadPDCNicIPAddress = '192.168.2.4'
$DomainpublicIPAddressName = "$DomainadPDCVMName-publicip"
$DomainadminUsername = 'ADmgmt'
$DomainadminPassword = 'Abcd1234#' | ConvertTo-SecureString -AsPlainText -Force
$DomainadVMSize = 'Standard_D1'
$DomainadAvailabilitySetName = 'avset20p101'
$DomaindomainName = 'azure.test'
$DomaindnsPrefix = "$DomainadPDCVMName-public"

$DomainadBDCVMName = 'sw20addc101'
$DomainadBDCNicName = "$DomainBDCVMName-nic"
$DomainadBDCNicIPAddress = '192.168.2.5'
$DomainBDCpublicIPAddressName = "$DomainadBDCVMName-publicip"
$DomainBDCdnsPrefix = "$DomainadBDCVMName-public"

#SQL Always On settings
$DeploySqlAlwaysOn = $True
$SqlAlwaysOnvmNamePrefix = 'swsql'


#App virtual machine settings
$DeployVirtualMachine = $False
$VMResourceGroupProduction = 'rg20p102'
$VMstorageAccountName = $StorageAccountProdName
$VMcomputerName = 'sw20p'
$vmcomputerNumberSuffix = 100
$VMcomputerAdminUserName = 'mgmtuser'
$VMcomputerAdminPassword = 'Abcd123##' | ConvertTo-SecureString -AsPlainText -Force
$VMcomputerVmSize = 'Standard_D1'
$VMcomputerWindowsOSVersion = '2012-R2-Datacenter'
$VMavailabilitySetName = 'avset20p100'
$VMvirtualNetworkName = $vNetName
$VMsubnetName = $vnetAppSubnetName
$VMnumberOfInstances = 2

#VM Domain join settings
$DeployVMDomainJoin = $True
$VMDomainJoincomputerName = 'swdj20p'
$VMDomainJoincomputerNumberSuffix = 100
$VMDomainJoinResourceGroup = 'rg20p105'
$VMDomainJoinUser = $DomainadminUsername
$VMDomainJoinPassword = $DomainadminPassword
$vmDomainJoinOuPath = ''
$vmDomainJoinDomainToJoin = $DomaindomainName
$VMDomainJoinnumberOfInstances = 3

#Management VM settings (other settings match DC VM settings)
$managementVMResourceGroup = 'rg20p103'
$managementVmComputerName = 'sw20p00'
$managementVmcomputerNumberSuffix = 1
$managementVmAvailabilitySetName = 'avset20p101'
$managementVmnumberOfInstances = 2

#endregion

#region AzureConnection
# Setup connection to Azure (RM)
$SubscriptionId = 'fbafe200-1e08-4846-a941-318a6a970b07'

Try{
    Get-AzureRmContext -ErrorAction Stop
    Get-AzureRmResourceGroup -ErrorAction Stop | Out-Null
}
Catch {
    Try {
            Add-AzureRmAccount -ErrorAction Stop
            Set-AzureRmContext -SubscriptionId $SubscriptionId -ErrorAction Stop
        }
    Catch{
        Throw "Failed to setup Azure connection with subscriptionId $SubscriptionId. Error: $_"
    }
}

If((Get-AzureRmContext).Subscription.SubscriptionId -ne $SubscriptionId){
    Try {
        Set-AzureRmContext -SubscriptionId $SubscriptionId -ErrorAction Stop
    }
    Catch {
        Try {
            Add-AzureRmAccount -ErrorAction Stop
            Set-AzureRmContext -SubscriptionId $SubscriptionId -ErrorAction Stop
        }
        Catch{
            Throw "Failed to setup Azure connection with subscriptionId $SubscriptionId. Error: $_"
        }
    }
}
#endregion

#region Setup InitialStorageAccount
# The first storage account cannot be created from template, creating in PowerShell

$StorageAccountName = 'sa20m001'
$StorageResourceGroupName = 'rg20m001'
$StorageAccountLocation = 'WestEurope'
$StorageEnvironment = 'Management'
$EnvironmentTag = @{Name = 'Environment' ; value = $StorageEnvironment}

If(-not(Get-AzureRmStorageAccount -Name $StorageAccountName)){
    New-AzureRmResourceGroup -Name $ResourceGroupName -Location $StorageAccountLocation -Tag $EnvironmentTag
    New-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -Type Standard_LRS -Location $StorageAccountLocation -Tags $EnvironmentTag
}

# Set storage account to use in current context
Set-AzureRmCurrentStorageAccount -ResourceGroupName $StorageResourceGroupName -StorageAccountName $StorageAccountName | Out-Null

#endregion

#region Setup Automation Account
If(-not(Get-AzureRmAutomationAccount -ResourceGroupName $AutomationAccountResourceGroup -Name $AutomationAccountName)) {
    New-AzureRmAutomationAccount -ResourceGroupName $AutomationAccountResourceGroup -Name $AutomationAccountName -Location $DefaultLocation -Plan $AutomationAccountPlan
}
$AutomationAccountCredential = New-Object System.Management.Automation.PSCredential ($DomainadminUsername, $DomainadminPassword)
If(-not(Get-AzureRmAutomationCredential -Name 'DomainCredential' -ResourceGroupName $AutomationAccountResourceGroup -AutomationAccountName $AutomationAccountName -ErrorAction SilentlyContinue)) {
    New-AzureRmAutomationCredential -Name 'DomainCredential' -Description 'Active Directory Domain Admin Credential' -Value $AutomationAccountCredential -ResourceGroupName $AutomationAccountResourceGroup -AutomationAccountName $AutomationAccountName
}
# Add AD credential to Automation Account

#endregion

#region Deploy Network Stack
$NetworkDeploymentParameters = @{
    ResourceGroupName = $NetworkResourceGroupName
    TemplateFile = "$PSScriptRoot\..\Templates\MMvnetdeploy.json"
    vNetName = $vNetName
    vNetPrefix = $vNetPrefix
    vNetPerimeterSubnetName = $vnetPerimeterSubnetName
    vNetPerimeterPrefix = $vnetPerimeterPrefix
    vNetFrontEndSubnetName = $vnetAppSubnetName
    vNetFrontEndPrefix = $vnetAppPrefix
    vNetBackEndSubnetName = $vnetBackEndSubnetName
    vNetBackEndPrefix = $vnetBackEndPrefix
    vnetGatewayPrefix = $vnetGatewaySubnetPrefix
}
If($DeployNetwork){ 
    New-AzureRmResourceGroup -Name $NetworkResourceGroupName -Location $DefaultLocation -Tag $NetworkResourceGroupTag -Force
    New-AzureRmResourceGroupDeployment @NetworkDeploymentParameters -Force
}
#endregion

#region VPN Configuration
If($DeployVPN){
    $VPNDeploymentParameters = @{
        ResourceGroupName = $NetworkResourceGroupName
        Templatefile = "$PSScriptRoot\..\Templates\MMvpndeploy.json"
        Location = $DefaultLocation
        virtualNetworkName = $vNetName
        vpnType = $VpnType
        localGatewayName = $VpnLocalGatewayName
        localGatewayIpAddress = $VpnLocalGatewayIpAddress
        localAddressPrefix = $VpnLocalAddressPrefix
        gatewayPublicIPName = $VpnGatewayPublicIPName
        gatewayName = $VpnGatewayName
        connectionName = $VpnConnectionName
        sharedKey = $VpnSharedKey
    }

    New-AzureRmResourceGroupDeployment @VPNDeploymentParameters -Force
}
#endregion

#region Storage Accounts
If($DeployStorage){
    $StorageAccountNonProdParameters = @{
        ResourceGroupName = $StorageNonProdResourceGroup
        StorageAccountName = $StorageAccountNonProdName
        StorageAccountType = $StorageAccountNonProdType
        TemplateFile = "$PSScriptRoot\..\Templates\MMstoragedeploy.json"
    }

    $StorageAccountProdParameters = @{
        ResourceGroupName = $StorageProdResourceGroup
        StorageAccountName = $StorageAccountProdName
        StorageAccountType = $StorageAccountProdType
        TemplateFile = "$PSScriptRoot\..\Templates\MMstoragedeploy.json"
    }

    New-AzureRmResourceGroup -Name $StorageNonProdResourceGroup -Location $DefaultLocation -Force
    New-AzureRmResourceGroupDeployment @StorageAccountNonProdParameters -Force

    New-AzureRmResourceGroup -Name $StorageProdResourceGroup -Location $DefaultLocation -Force
    New-AzureRmResourceGroupDeployment @StorageAccountProdParameters -Force
}
#endregion

#region Deploy Active Directory 
$ActiveDirectoryDeployParameters = @{
    StorageAccountName = $DomainStorageAccountName
    location = $Domainlocation	
    virtualNetworkName = $DomainvirtualNetworkName
    adSubnetName = $DomainadSubnetName
    adPDCVMName = $DomainadPDCVMName
    adPDCNicName = $DomainadPDCNicName
    adPDCNicIPAddress = $DomainadPDCNicIPAddress
    publicIPAddressName = $DomainpublicIPAddressName
    adminUsername = $DomainadminUsername
    adminPassword = $DomainadminPassword
    adVMSize = $DomainadVMSize
    adAvailabilitySetName = $DomainadAvailabilitySetName
    domainName = $DomaindomainName
    dnsPrefix = $DomaindnsPrefix
    ResourceGroupName = $DomainResourceGroup
    TemplateFile = "$PSScriptRoot\..\Templates\MMActiveDirectory.json"
    networkResourceGroup = $NetworkResourceGroupName

}

# Deploy Domain Controller #2
$ActiveDirectoryDeployBDCParameters = @{
    StorageAccountName = $DomainStorageAccountName
    location = $Domainlocation	
    virtualNetworkName = $DomainvirtualNetworkName
    adSubnetName = $DomainadSubnetName
    adBDCVMName = $DomainadBDCVMName
    adBDCNicName = $DomainadBDCNicName
    adBDCNicIPAddress = $DomainadBDCNicIPAddress
    publicIPAddressName = $DomainBDCpublicIPAddressName
    adminUsername = $DomainadminUsername
    adminPassword = $DomainadminPassword
    adVMSize = $DomainadVMSize
    adAvailabilitySetName = $DomainadAvailabilitySetName
    domainName = $DomaindomainName
    dnsPrefix = $DomainBDCdnsPrefix
    ResourceGroupName = $DomainResourceGroup
    TemplateFile = "$PSScriptRoot\..\Templates\MMActiveDirectoryBDC.json"
    networkResourceGroup = $NetworkResourceGroupName
}

If($DeployActiveDirectory) {
    New-AzureRmResourceGroup -Name $DomainResourceGroup -Location $DefaultLocation -Force
    New-AzureRmResourceGroupDeployment @ActiveDirectoryDeployParameters -Force

    # Need to update vNet with new DNS
    $NetworkDeploymentParameters.Templatefile = "$PSScriptRoot\..\Templates\MMvnetdeploywDNS.json"
    $NetworkDeploymentParameters.Add('vNetDNSServers',[array]$DomainadPDCNicIPAddress)

    # Deploy DNS Changes
    New-AzureRmResourceGroupDeployment @NetworkDeploymentParameters -Force

    #Deploy the Backup DC
    New-AzureRmResourceGroupDeployment @ActiveDirectoryDeployBDCParameters -Force

    # Deploy DNS changes, adding secondary DC
    $NetworkDeploymentParameters.vNetDNSServers = @($DomainadPDCNicIPAddress,$DomainadBDCNicIPAddress)
    New-AzureRmResourceGroupDeployment @NetworkDeploymentParameters -Force
}
#endregion

#region Deploy Virtual Machines
$VMDeployParameters = @{
    ResourceGroupName = $VMResourceGroupProduction
    TemplateFile = "$PSScriptRoot\..\Templates\MMdeployvm.json"
    storageAccountName  = $VMstorageAccountName    
    computerName = $VMcomputerName
    computerAdminUserName = $VMcomputerAdminUserName
    computerAdminPassword = $VMcomputerAdminPassword
    computerVmSize = $VMcomputerVmSize
    computerWindowsOSVersion = $VMcomputerWindowsOSVersion
    availabilitySetName = $VMavailabilitySetName
    networkResourceGroup = $NetworkResourceGroupName
    virtualNetworkName = $VMvirtualNetworkName
    subnetName = $VMsubnetName
    numberOfInstances = $VMnumberOfInstances
    computerNumberSuffix = $vmcomputerNumberSuffix
}

If($DeployVirtualMachine) {
    New-AzureRmResourceGroup -Name $VMResourceGroupProduction -Location $DefaultLocation -Force
    New-AzureRmResourceGroupDeployment @VMDeployParameters -Force

    $ManagementVmDeployParameters = $VMDeployParameters
    $ManagementVmDeployParameters.ResourceGroupName = $managementVMResourceGroup
    $ManagementVmDeployParameters.availabilitySetName = $managementVmAvailabilitySetName
    $ManagementVmDeployParameters.computerName = $managementVmComputerName
    $ManagementVmDeployParameters.computerNumberSuffix = $managementVmcomputerNumberSuffix
    $ManagementVmDeployParameters.numberOfInstances = $managementVmnumberOfInstances

    New-AzureRmResourceGroup -Name $ManagementVmDeployParameters.ResourceGroupName -Location $DefaultLocation -Force
    New-AzureRmResourceGroupDeployment @ManagementVmDeployParameters -Force

}
#endregion


#region Deploy Virtual machine domain joined
$VMDomainJoinDeployParameters = $VMDeployParameters
$VMDomainJoinDeployParameters.TemplateFile = "$PSScriptRoot\..\Templates\MMdeployvmdomainjoined.json"
$VMDomainJoinDeployParameters.computerName = $VMDomainJoincomputerName
$VMDomainJoinDeployParameters.computerNumberSuffix = $VMDomainJoincomputerNumberSuffix
$VMDomainJoinDeployParameters.ResourceGroupName = $VMDomainJoinResourceGroup
$VMDomainJoinDeployParameters.Add('domainToJoin',$vmDomainJoinDomainToJoin)
$VMDomainJoinDeployParameters.Add('domainUsername',$VMDomainJoinUser)
$VMDomainJoinDeployParameters.Add('domainPassword',$VMDomainJoinPassword)
#$VMDomainJoinDeployParameters.Add('ouPath',$vmDomainJoinOuPath)
$VMDomainJoinDeployParameters.numberOfInstances = $VMDomainJoinnumberOfInstances

If($DeployVMDomainJoin) {
    New-AzureRMResourceGroup -Name $VMDomainJoinResourceGroup -Location $DefaultLocation -Force
    New-AzureRmResourceGroupDeployment @VMDomainJoinDeployParameters
}