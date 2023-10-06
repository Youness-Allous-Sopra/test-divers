#---------------------------------------------------------
# Creation groupe de ressources
#----------------------------------------------------------
resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.environement}"
  location = "francecentral"
  #tags     = var.tags
}


#-------------------------------------
# Creation VNET 
#-------------------------------------
resource "azurerm_virtual_network" "vnet-1" {
  name                = "vnet-${var.environement}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = local.env_reseau[var.environement]
  # address_space       = var.vnet_address_space
  #tags                = merge({ "ResourceName" = lower("${var.spoke_vnet_name}") }, var.tags, )
}

#-----------------------------------------------------
# Creation des subnets
#-----------------------------------------------------
resource "azurerm_subnet" "subnet-app-service-in" {
  name                 = "sub-${var.environement}-aps-inbound"
  virtual_network_name = azurerm_virtual_network.vnet-1.name
  resource_group_name  = azurerm_virtual_network.vnet-1.resource_group_name
  address_prefixes     = ["${cidrhost(element(local.env_reseau[var.environement],0),0)}/26"]
  #address_prefixes     = ["${cidrhost(element(var.vnet_address_space,0),0)}/26"]
}

resource "azurerm_subnet" "subnet-app-service-out" {
  name                 = "sub-${var.environement}-aps-outbound"
  virtual_network_name = azurerm_virtual_network.vnet-1.name
  resource_group_name  = azurerm_virtual_network.vnet-1.resource_group_name
  address_prefixes     = ["${cidrhost(element(local.env_reseau[var.environement],0),64)}/26"]

  delegation {
    name = "delegation"

    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action",
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
    }
  }
}

resource "azurerm_subnet" "subnet-mongodb-1" {
  name                 = "sub-${var.environement}-mongodb"
  virtual_network_name = azurerm_virtual_network.vnet-1.name
  resource_group_name  = azurerm_virtual_network.vnet-1.resource_group_name
  address_prefixes     = ["${cidrhost(element(local.env_reseau[var.environement],0),128)}/26"]
}


#-----------------------------------------------------
# Creation des nsgs et associations aux subnets
#-----------------------------------------------------
resource "azurerm_network_security_group" "nsg-1" {
  name                = "nsg-${var.environement}-aps-inbound"
  location            = azurerm_virtual_network.vnet-1.location
  resource_group_name = azurerm_subnet.subnet-app-service-in.resource_group_name

  security_rule {
    name                       = "allow-http"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-https"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  #tags = 
}

resource "azurerm_subnet_network_security_group_association" "nsg-assoc-1" {
  subnet_id                 = azurerm_subnet.subnet-app-service-in.id
  network_security_group_id = azurerm_network_security_group.nsg-1.id
}


/* #-------------------------------------------------------------
# Route_table pour forcer le traffic a passer par la Firewall
#-------------------------------------------------------------
resource "azurerm_route_table" "rtout" {
  name                = "rte-${var.environement}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  #tags                = merge({ "ResourceName" = "rte-${var.environement}" }, var.tags, )
  disable_bgp_route_propagation = true
}

resource "azurerm_subnet_route_table_association" "rtassoc" {
  subnet_id      = azurerm_subnet.subnet-app-service-in.id
  route_table_id = azurerm_route_table.rtout.id
}

resource "azurerm_route" "rt" {
  for_each      = { for idx, cidr_block in var.address_prefix_to_fw_route : cidr_block => idx}
  name                   = format( "route-to-firewall-%02d" , each.value +1 )
  resource_group_name    = azurerm_resource_group.rg.name
  route_table_name       = azurerm_route_table.rtout.name
  address_prefix         = "${each.key}"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = data.azurerm_firewall.firewall.ip_configuration[0].private_ip_address
}


#---------------------------------------------
# Liaison du Spoke Vnet au Hub Private DNS Zone
#---------------------------------------------
resource "azurerm_private_dns_zone_virtual_network_link" "dzvlink" {
  provider              = azurerm.hub
  count                 = var.private_dns_zone_name != null ? 1 : 0
  name                  = lower("${var.private_dns_zone_name}-link-to-hub")
  resource_group_name   = element(split("/", data.azurerm_virtual_network.vnet_hub.id), 4)
  virtual_network_id    = azurerm_virtual_network.vnet-1.id
  private_dns_zone_name = var.private_dns_zone_name
  registration_enabled  = true
  #tags                  = merge({ "ResourceName" = format("%s", lower("${var.private_dns_zone_name}-link-to-hub")) }, var.tags, )
}


#-----------------------------------------------
# Peering entre Hub et Spoke Virtual Network
#-----------------------------------------------
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = lower("peering-${element(split("/", data.azurerm_virtual_network.vnet_hub.id), 8)}")
  resource_group_name          = azurerm_virtual_network.vnet-1.resource_group_name
  virtual_network_name         = azurerm_virtual_network.vnet-1.name
  remote_virtual_network_id    = data.azurerm_virtual_network.vnet_hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  provider                     = azurerm.hub
  name                         = lower("peering-${element(split("/", data.azurerm_virtual_network.vnet_hub.id), 8)}-to-vnet${var.environement}")
  resource_group_name          = element(split("/", data.azurerm_virtual_network.vnet_hub.id), 4)
  virtual_network_name         = element(split("/", data.azurerm_virtual_network.vnet_hub.id), 8)
  remote_virtual_network_id    = azurerm_virtual_network.vnet-1.id
  allow_gateway_transit        = false
  allow_forwarded_traffic      = false
  allow_virtual_network_access = true
  use_remote_gateways          = false
} */