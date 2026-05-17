
data "yandex_compute_image" "ubuntu_2204_lts" {
  family = "ubuntu-2204-lts"
}



resource "yandex_compute_instance" "web" {
  count       = 2
  name        = "web-${count.index + 1}"
  hostname    = "web-${count.index + 1}"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores         = 2
    memory        = 1
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = 10
    }
  }


  metadata = {
  user-data          = file("./cloud-init.yml")
  serial-port-enable = 1
}

  scheduling_policy { preemptible = true }

  network_interface {
    subnet_id          = yandex_vpc_subnet.develop_a.id
    nat                = true 
    security_group_ids = [yandex_vpc_security_group.web_sg.id]
  }
}


resource "yandex_lb_target_group" "web_tg" {
  name = "web-target-group"

  dynamic "target" {
    for_each = yandex_compute_instance.web
    content {
      subnet_id = yandex_vpc_subnet.develop_a.id
      address   = target.value.network_interface[0].ip_address
    }
  }
}


resource "yandex_lb_network_load_balancer" "web_lb" {
  name = "web-load-balancer"
  type = "external"


  listener {
    name = "http-listener"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }


  attached_target_group {
    target_group_id = yandex_lb_target_group.web_tg.id

    healthcheck {
      name                = "http-healthcheck"
      interval            = 5   
      timeout             = 3   
      unhealthy_threshold = 3   
      healthy_threshold   = 2   

      http_options {
        port = 80
        path = "/"
      }
    }
  }
}


resource "local_file" "inventory" {
  content  = <<-INI
  [webservers]
  ${yandex_compute_instance.web[0].network_interface.0.nat_ip_address}
  ${yandex_compute_instance.web[1].network_interface.0.nat_ip_address}
  INI
  filename = "./hosts.ini"
}
