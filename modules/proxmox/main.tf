terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.78"
    }
  }
}

locals {
  vms = {
    # ★ 추가: longhorn_disk 필드 추가 (마스터 0, 워커 30)
    "k8s-master-01" = { vmid = 301, ip = "20.20.20.241", cores = 2, memory = 4096, disk = 30, longhorn_disk = 0 }
    "k8s-master-02" = { vmid = 302, ip = "20.20.20.242", cores = 2, memory = 4096, disk = 30, longhorn_disk = 0 }
    "k8s-master-03" = { vmid = 303, ip = "20.20.20.243", cores = 2, memory = 4096, disk = 30, longhorn_disk = 0 }
    "k8s-worker-01" = { vmid = 304, ip = "20.20.20.244", cores = 4, memory = 16384, disk = 40, longhorn_disk = 30 }
    "k8s-worker-02" = { vmid = 305, ip = "20.20.20.245", cores = 4, memory = 16384, disk = 40, longhorn_disk = 30 }
    "k8s-worker-03" = { vmid = 306, ip = "20.20.20.246", cores = 4, memory = 16384, disk = 40, longhorn_disk = 30 }
  }
}

resource "proxmox_virtual_environment_vm" "k8s_nodes" {
  for_each  = local.vms
  name      = each.key
  vm_id     = each.value.vmid
  node_name = var.proxmox_node_name

  clone {
    vm_id = 9000
    full  = true
  }

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
  }

  # 기존 OS 디스크 (변경 없음)
  disk {
    datastore_id = "vmdata"
    interface    = "scsi0"
    size         = each.value.disk
    discard      = "on"
  }

  # ★ 추가: Longhorn 전용 디스크 (워커 노드만, longhorn_disk > 0 일 때만 생성)
  dynamic "disk" {
    for_each = each.value.longhorn_disk > 0 ? [1] : []
    content {
      datastore_id = "vmdata"
      interface    = "scsi1"
      size         = each.value.longhorn_disk
      discard      = "on"
    }
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  initialization {
    datastore_id = "vmdata"
    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = "20.20.20.230"
      }
    }
    user_account {
      username = "ubuntu"
      keys     = [var.ssh_public_key]
    }
  }

  # ★ 추가: 기존 VM 재생성 방지 (clone, initialization은 최초 생성 시에만 적용)
  lifecycle {
    ignore_changes = [
      clone,
      initialization,
    ]
  }
}
