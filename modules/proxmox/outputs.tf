output "vm_ips" {
  value = { for k, v in local.vms : k => v.ip }
}
