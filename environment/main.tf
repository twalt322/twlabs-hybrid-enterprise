resource "azurerm_virtual_network_gateway" "vpn" {
  name                = "vng-twlabs-hybrid"
  location            = local.location
  resource_group_name = data.terraform_remote_state.foundation.outputs.resource_group_name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  bgp_enabled   = false

  sku = "VpnGw1AZ"

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = data.terraform_remote_state.foundation.outputs.vpn_public_ip_id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = data.terraform_remote_state.foundation.outputs.gateway_subnet_id
  }

  tags = local.common_tags
}

resource "azurerm_local_network_gateway" "home" {
  name                = "lng-twlabs-home"
  location            = local.location
  resource_group_name = data.terraform_remote_state.foundation.outputs.resource_group_name

  gateway_address = var.home_public_ip

  address_space = [
    "192.168.40.0/24"
  ]

  tags = local.common_tags
}

resource "azurerm_virtual_network_gateway_connection" "s2s" {
  name                = "conn-twlabs-s2s"
  location            = local.location
  resource_group_name = data.terraform_remote_state.foundation.outputs.resource_group_name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vpn.id
  local_network_gateway_id   = azurerm_local_network_gateway.home.id

  shared_key = data.azurerm_key_vault_secret.vpn_shared_key.value

  tags = local.common_tags
}

module "compute" {
  source = "../modules/compute"

  resource_group_name  = data.terraform_remote_state.foundation.outputs.resource_group_name
  location             = data.terraform_remote_state.foundation.outputs.location
  vmss_name            = "vmss-twlabs-workload"
  vm_size              = "Standard_D2alds_v7"
  instance_count       = 2
  subnet_id            = data.terraform_remote_state.foundation.outputs.workload_subnet_id
  admin_username       = "twlabsadmin"
  admin_ssh_public_key = file("~/.ssh/twlabs_hybrid_vmss.pub")

  backend_address_pool_ids = [
    azurerm_lb_backend_address_pool.vmss.id
  ]

  tags = local.common_tags
}

resource "azurerm_role_assignment" "vmss_acr_pull" {
  scope                = data.terraform_remote_state.foundation.outputs.acr_id
  role_definition_name = "AcrPull"
  principal_id         = module.compute.principal_id
}

resource "azurerm_role_assignment" "vmss_key_vault_secrets_user" {
  scope                = data.terraform_remote_state.foundation.outputs.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.compute.principal_id
}

resource "azurerm_lb" "internal" {
  name                = "lb-twlabs-internal"
  location            = data.terraform_remote_state.foundation.outputs.location
  resource_group_name = data.terraform_remote_state.foundation.outputs.resource_group_name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "internal-frontend"
    subnet_id                     = data.terraform_remote_state.foundation.outputs.workload_subnet_id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.40.100"
  }

  tags = local.common_tags
}

resource "azurerm_lb_backend_address_pool" "vmss" {
  name            = "backend-vmss"
  loadbalancer_id = azurerm_lb.internal.id
}

resource "azurerm_lb_probe" "http" {
  name            = "http-probe"
  loadbalancer_id = azurerm_lb.internal.id
  protocol        = "Tcp"
  port            = 80
}

resource "azurerm_lb_rule" "http" {
  name                           = "http-rule"
  loadbalancer_id                = azurerm_lb.internal.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "internal-frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.vmss.id]
  probe_id                       = azurerm_lb_probe.http.id
}

resource "azurerm_lb_probe" "https" {
  loadbalancer_id = azurerm_lb.internal.id
  name            = "probe-https"
  port            = 443
  protocol        = "Tcp"
}

resource "azurerm_lb_rule" "https" {
  loadbalancer_id                = azurerm_lb.internal.id
  name                           = "rule-https"
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = "internal-frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.vmss.id]
  probe_id                       = azurerm_lb_probe.https.id
}

resource "azurerm_public_ip" "nat" {
  name                = "pip-nat-gateway"
  location            = local.location
  resource_group_name = data.terraform_remote_state.foundation.outputs.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1"]

  tags = local.common_tags
}

resource "azurerm_nat_gateway" "nat" {
  name                    = "ng-twlabs-hybrid"
  location                = local.location
  resource_group_name     = data.terraform_remote_state.foundation.outputs.resource_group_name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  zones                   = ["1"]

  tags = local.common_tags
}

resource "azurerm_nat_gateway_public_ip_association" "nat_pip" {
  nat_gateway_id       = azurerm_nat_gateway.nat.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "nat_snet" {
  subnet_id      = data.terraform_remote_state.foundation.outputs.workload_subnet_id
  nat_gateway_id = azurerm_nat_gateway.nat.id
}

resource "azurerm_virtual_machine_scale_set_extension" "ama" {
  name                         = "AzureMonitorLinuxAgent"
  virtual_machine_scale_set_id = module.compute.vmss_id

  publisher                 = "Microsoft.Azure.Monitor"
  type                      = "AzureMonitorLinuxAgent"
  type_handler_version      = "1.40"
  automatic_upgrade_enabled = true
}

resource "azurerm_monitor_data_collection_rule" "vmss" {
  name                = "dcr-twlabs-vmss"
  resource_group_name = data.terraform_remote_state.foundation.outputs.resource_group_name
  location            = local.location
  kind                = "Linux"

  destinations {
    log_analytics {
      workspace_resource_id = data.terraform_remote_state.foundation.outputs.log_analytics_workspace_id
      name                  = "law-twlabs-hybrid"
    }
  }

  data_flow {
    streams      = ["Microsoft-Syslog"]
    destinations = ["law-twlabs-hybrid"]
  }

  data_flow {
    streams      = ["Microsoft-Perf"]
    destinations = ["law-twlabs-hybrid"]
  }

  data_sources {
    syslog {
      name           = "linux-syslog"
      facility_names = ["syslog", "daemon", "auth", "authpriv"]
      log_levels     = ["Warning", "Error", "Critical", "Alert", "Emergency"]
      streams        = ["Microsoft-Syslog"]
    }

    performance_counter {
      name                          = "linux-performance"
      streams                       = ["Microsoft-Perf"]
      sampling_frequency_in_seconds = 60

      counter_specifiers = [
        "\\Processor(_Total)\\% Processor Time",
        "\\Memory\\Committed Bytes",
        "\\LogicalDisk(_Total)\\Free Megabytes",
        "\\PhysicalDisk(_Total)\\Avg. Disk Queue Length"
      ]
    }
  }

  tags = local.common_tags
}

resource "azurerm_monitor_data_collection_rule_association" "vmss" {
  name                    = "dcra-twlabs-vmss"
  target_resource_id      = module.compute.vmss_id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.vmss.id
}

resource "azurerm_monitor_metric_alert" "vmss_high_cpu" {
  name                = "alert-vmss-high-cpu"
  resource_group_name = data.terraform_remote_state.foundation.outputs.resource_group_name
  scopes              = [module.compute.vmss_id]

  description = "Alerts when average VMSS CPU utilization exceeds 80 percent."
  severity    = 2
  frequency   = "PT1M"
  window_size = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachineScaleSets"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  tags = local.common_tags
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "vmss_low_disk" {
  name                = "alert-vmss-low-disk"
  resource_group_name = data.terraform_remote_state.foundation.outputs.resource_group_name
  location            = local.location

  scopes = [
    data.terraform_remote_state.foundation.outputs.log_analytics_workspace_id
  ]

  description          = "Alerts when root filesystem free space drops below 15 percent on a VMSS instance."
  severity             = 2
  evaluation_frequency = "PT5M"
  window_duration      = "PT15M"

  criteria {
    query = <<-QUERY
      Perf
      | where ObjectName == "Logical Disk"
      | where CounterName == "% Free Space"
      | where CounterPath endswith "\\Logical Disk(/)\\% Free Space"
      | summarize AvgFreeSpace = avg(CounterValue) by Computer
    QUERY

    time_aggregation_method = "Average"
    metric_measure_column   = "AvgFreeSpace"
    operator                = "LessThan"
    threshold               = 15

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  tags = local.common_tags
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "vmss_missing_heartbeat" {
  name                = "alert-vmss-missing-heartbeat"
  resource_group_name = data.terraform_remote_state.foundation.outputs.resource_group_name
  location            = local.location

  scopes = [
    data.terraform_remote_state.foundation.outputs.log_analytics_workspace_id
  ]

  description          = "Alerts when a VMSS instance stops sending Azure Monitor Agent heartbeats."
  severity             = 1
  evaluation_frequency = "PT5M"
  window_duration      = "PT10M"

  criteria {
    query = <<-QUERY
      Heartbeat
      | where Category == "Azure Monitor Agent"
      | summarize LastHeartbeat = max(TimeGenerated) by Computer
      | extend MinutesSinceHeartbeat = datetime_diff("minute", now(), LastHeartbeat) * -1
    QUERY

    time_aggregation_method = "Maximum"
    metric_measure_column   = "MinutesSinceHeartbeat"
    operator                = "GreaterThan"
    threshold               = 5

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  tags = local.common_tags
}