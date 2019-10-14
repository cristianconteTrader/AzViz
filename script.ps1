# Start-Process chrome 'http://armviz.io'
# Start-Process chrome 'https://github.com/Azure/azure-quickstart-templates/tree/master/101-vm-with-rdp-port'

# using Azure Network watcher to generate resource associations
# which will be used to build the Azure Network topolgy
$params = @{
    Name          = 'NetworkWatcher_centralindia'
    ResourceGroup = 'NetworkWatcherRG'
}

$networkWatcher = Get-AzNetworkWatcher @params 
$ResourceGroups = Get-AzResourceGroup | 
    Where-Object { $_.ResourceGroupName -in 'TEST-RESOURCE-GROUP' } |
    # Where-Object { $_.ResourceGroupName -in 'my-resource-group','DEMO-RESOURCE-GROUP', 'test-resource-group', 'DEMO2-RESOURCE-GROUP'  } |
    ForEach-Object ResourceGroupName  

<#
$Topology = Get-AzNetworkWatcherTopology -NetworkWatcher $networkWatcher -TargetResourceGroupName 'test-resource-group' -Verbose
$Topology.Resources 
#>

. C:\Users\Administrator\Desktop\repo\AzViz\hashtable.ps1
. C:\Users\Administrator\Desktop\repo\AzViz\src\private\Get-ImageNode.ps1

#region defaults
$rank = @{
    publicIPAddresses     = 0
    loadBalancers         = 1
    virtualNetworks       = 2 
    networkSecurityGroups = 3
    networkInterfaces     = 4
    virtualMachines       = 5
}

$UniqueIdentifier = 0
$Tier = 0

$Shapes = @{
    loadBalancers                            = 'diamond'
    publicIPAddresses                        = 'octagon'
    networkInterfaces                        = 'component'
    virtualMachines                          = 'box3d'
    'loadBalancers/backendAddressPools'      = 'rect'
    'loadBalancers/frontendIPConfigurations' = 'rect'
    'virtualNetworks'                        = 'oval'
    'networkSecurityGroups'                  = 'oval'
}

$Style = @{
    loadBalancers                            = 'filled'
    publicIPAddresses                        = 'filled'
    networkInterfaces                        = 'filled'
    virtualMachines                          = 'filled'
    'loadBalancers/backendAddressPools'      = 'filled'
    'loadBalancers/frontendIPConfigurations' = 'filled'
    'virtualNetworks'                        = 'dotted'
    'networkSecurityGroups'                  = 'filled'
}

$Color = @{
    loadBalancers                            = 'greenyellow'
    publicIPAddresses                        = 'gold'
    networkInterfaces                        = 'skyblue'
    'loadBalancers/frontendIPConfigurations' = 'lightsalmon'
    virtualMachines                          = 'darkolivegreen3'
    'loadBalancers/backendAddressPools'      = 'crimson'
    'virtualNetworks'                        = 'navy'
    'networkSecurityGroups'                  = 'azure'
}
#endregion defaults

#region graph-generation
Write-Host "[+] Starting topology graph generation`n`t- Target Resource Groups: [$ResourceGroups]`n`t- Network Watcher: [$($networkWatcher.Name)]" -ForegroundColor DarkCyan
Graph 'AzureTopology' @{overlap = 'false'; splines = 'true' ; rankdir = 'TB' } {
    foreach ($ResourceGroup in $ResourceGroups) {
        Write-Host "`t[+] Working on `"Graph$UniqueIdentifier`" for ResourceGroup: `"$ResourceGroup`"" -ForegroundColor Yellow
        SubGraph "$($ResourceGroup.Replace('-', ''))" @{label = $ResourceGroup; labelloc = 'b' } {
            Write-Host "`t`t[+] Fetching Network topology of ResourceGroup: `"$ResourceGroup`"" -ForegroundColor Green
            $Topology = Get-AzNetworkWatcherTopology -NetworkWatcher $networkWatcher -TargetResourceGroupName $ResourceGroup -Verbose
            
            #region parsing-topology-and-finding-associations

            # parse topology to find nodes and their associations and rank them.
            Write-Host "`t`t[+] Parsing Network topology objects to find associations" -ForegroundColor Green
            $data = @()
            $data += $Topology.Resources | 
                Select-Object @{n = 'from'; e = { $_.name } }, 
                @{n = 'FromCategory'; e = { $_.id.Split('/', 8)[-1] } },
                Associations, 
                @{n = 'To'; e = { ($_.AssociationText | ConvertFrom-Json) | Select-Object name, AssociationType, resourceID } } |
                ForEach-Object {
                    if ($_.to) {
                        Foreach ($to in $_.to) {
                            $i = 1
                            $fromcateg = $_.FromCategory.split('/', 4).ForEach( { if ($i % 2) { $_ }; $i = $i + 1 }) -join '/'
                            [PSCustomObject]@{
                                fromcateg   = $fromCateg
                                from        = $_.from
                                to          = $to.name
                                association = $to.associationType
                                toCateg     = (($to.resourceID -split 'providers/')[1] -split '/')[1]
                                rank        = $rank["$($FromCateg.split('/')[0])"]
                            }
                        }
                    }
                    else {
                        $i = 1
                        $fromcateg = $_.FromCategory.split('/', 4).ForEach( { if ($i % 2) { $_ }; $i = $i + 1 }) -join '/'
                        [PSCustomObject]@{
                            fromcateg   = $fromCateg
                            from        = $_.from
                            to          = ''
                            association = ''
                            toCateg     = ''
                            rank        = $rank["$($FromCateg.split('/')[0])"]
                        }
                    }
                } | 
                Sort-Object Rank
            #endregion parsing-topology-and-finding-associations
          
            #region test

            #region plotting-edges-to-nodes
            $data | 
                Where-Object to | 
                ForEach-Object {
                    if ($_.Association -eq 'Contains') {
                        Edge -From "$UniqueIdentifier$($_.from)" `
                            -to "$UniqueIdentifier$($_.to)" `
                            -Attributes @{
                            arrowhead = 'box';
                            style     = 'dotted';
                            label     = ' Contains'
                        }
                    }
                    else {
                        Edge -From "$UniqueIdentifier$($_.from)" `
                            -to "$UniqueIdentifier$($_.to)" 
                    }
                }
            #endregion plotting-edges-to-nodes

            <#
            #region plotting-all-publicIP-nodes
            $pubip = @()
            $pubip += $data | 
                Where-Object { 
                    $_.fromcateg -like 'publicIPAddresses'
                } | 
                Select-Object *, @{n = 'Category'; e = { 'fromcateg' } }

            if ($pubip) {
                $pubip | ForEach-Object {
                    if ($_.Category -eq 'fromcateg') {
                        $from = $_.from
                        Get-ImageNode -Name "$UniqueIdentifier$from" -Rows $From -Type $_.fromcateg   
                    }
                    else {
                        $to = $_.to
                        Get-ImageNode -Name "$UniqueIdentifier$to" -Rows $to -Type $_.toCateg   

                    }
                }
            }
            #endregion plotting-all-publicIP-nodes
            
            #region plotting-all-loadbalancer-nodes
            $lb = @()
            $lb += $data | 
                Where-Object { $_.fromcateg -like 'loadbalancers' } |
                Select-Object *, @{n = 'Category'; e = { 'fromcateg' } }
            $lb += $data | 
                Where-Object { $_.tocateg -like 'loadbalancers' } |
                Select-Object *, @{n = 'Category'; e = { 'tocateg' } }
            if ($lb) {
                $tier++
                SubGraph "${UniqueIdentifier}loadbalancer" @{
                    style    = 'dashed';
                    label    = "tier-$Tier";
                    labelloc = 'tl' 
                } {
                    $lb | ForEach-Object {
                        if ($_.Category -eq 'fromcateg') {
                            $from = $_.from

                        Get-ImageNode -Name "$UniqueIdentifier$from" -Rows $from -Type $_.fromcateg   

                        }
                        else {
                            $to = $_.to
                        Get-ImageNode -Name "$UniqueIdentifier$to" -Rows $to -Type $_.toCateg   

                        }
                    }
                }
            }
            #endregion plotting-all-loadbalancer-nodes

            #region plotting-all-VM-nodes
            $vm = @()
            $ShouldMatch = 'networkInterfaces', 'virtualMachines'
            $vm += $data | 
                Where-Object { $_.fromcateg -in $ShouldMatch } |
                Select-Object *, @{n = 'Category'; e = { 'fromcateg' } }

            if ($vm) {
                $tier++
                SubGraph "${UniqueIdentifier}virtualmachine" @{style = 'dashed'; label = "tier-$Tier"; labelloc = 'tl' } {
                    $vm | ForEach-Object {
                        if ($_.Category -eq 'fromcateg') {
                            $from = $_.from
                        # Get-ImageNode -Name "$UniqueIdentifier$from" -Rows $from -Type $_.fromCateg   

                        }
                        else {
                            $to = $_.to
                            # Get-ImageNode -Name "$UniqueIdentifier$to" -Rows $to -Type $_.toCateg   

                        }
                    }
                }
            }
            #endregion plotting-all-VM-nodes

            #endregion test
#>
            #region plotting-all-remaining-nodes
            $remaining = @()
            # $ShouldMatch = 'publicIPAddresses', 'loadBalancers', 'networkInterfaces', 'virtualMachines'
            $remaining += $data | Where-Object { $_.fromcateg -notin $ShouldMatch } |
            Select-Object *, @{n = 'Category'; e = { 'fromcateg' } }
        $remaining += $data | Where-Object { $_.tocateg -notin $ShouldMatch } |
        Select-Object *, @{n = 'Category'; e = { 'tocateg' } }
 
    if ($remaining) {
        $remaining | ForEach-Object {
            if ($_.Category -eq 'fromcateg') {
                $from = $_.from
                $Node = Get-ImageNode -Name "$UniqueIdentifier$from" -Rows $from -Type $_.fromCateg   
                $Node
                Write-Host 'fromcateg: ' $_.fromcateg "Name: $From" -ForegroundColor Yellow
                Write-Host $Node
            }
            # else {
            #     $to = $_.to
            #     if (![string]::IsNullOrEmpty($to)) {
            #     $node =   Get-ImageNode -Name "$UniqueIdentifier$to" -Rows $to -Type $_.toCateg   
            #         $node
            #         Write-Host 'tocateg: ' $_.tocateg "Name: $To"  -ForegroundColor Yellow
            #         Write-Host $Node

            #     }
            # }
        }
    }
    #endregion plotting-all-remaining-nodes

}
$UniqueIdentifier = $UniqueIdentifier + 1
} 
} | Export-PSGraph -ShowGraph
#endregion graph-generation