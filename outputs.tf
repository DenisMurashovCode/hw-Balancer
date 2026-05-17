
output "web_vm_ips" {
  description = "Публичные IP-адреса веб-серверов"
  value = {
    for vm in yandex_compute_instance.web :
    vm.name => vm.network_interface[0].nat_ip_address
  }
}

output "load_balancer_ip" {
  description = "Внешний IP-адрес балансировщика"
  value = flatten([
    for listener in yandex_lb_network_load_balancer.web_lb.listener :
    [for spec in listener.external_address_spec : spec.address]
  ])
}
