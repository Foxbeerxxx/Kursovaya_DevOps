# main.tf — разворачивает web-кластер, балансировку и сеть

module "vpc" {
  source  = "terraform-yandex-modules/vpc/yandex"
  version = "0.13.0"

  network_name = "webnet"
  zone        = "ru-central1-a"

  subnets = [
    { zone = "ru-central1-a", cidr = "10.10.1.0/24" },
    { zone = "ru-central1-b", cidr = "10.10.2.0/24" },
    { zone = "ru-central1-c", cidr = "10.10.3.0/24" },
  ]
}

resource "yandex_vpc_security_group" "web_sg" {
  name       = "web-sg"
  network_id = module.vpc.network_id

  ingress {
    protocol       = "TCP"
    description    = "Allow HTTP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "Allow SSH"
    port           = 22
    security_group_id = yandex_vpc_security_group.bastion_sg.id
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_compute_instance" "web" {
  count = 2

  name        = "web-${count.index + 1}"
  zone        = element(["ru-central1-a", "ru-central1-b"], count.index)
  hostname    = "web-${count.index + 1}"
  platform_id = "standard-v1"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd8q1vfvqgb9g26r8j5o" # Ubuntu 22.04
      type     = "network-ssd"
      size     = 10
    }
  }

  network_interface {
    subnet_id          = element(module.vpc.subnet_ids, count.index)
    nat                = false
    security_group_ids = [yandex_vpc_security_group.web_sg.id]
  }

  metadata = {
    user-data = file("cloud-init.yml")
  }
}

resource "yandex_lb_target_group" "web_tg" {
  name = "web-target-group"

  target {
    subnet_id = module.vpc.subnet_ids[0]
    address   = yandex_compute_instance.web[0].network_interface.0.ip_address
  }

  target {
    subnet_id = module.vpc.subnet_ids[1]
    address   = yandex_compute_instance.web[1].network_interface.0.ip_address
  }
}

resource "yandex_lb_backend_group" "web_backend" {
  name = "web-backend"

  http_backend {
    name             = "backend"
    weight           = 1
    port             = 80
    target_group_ids = [yandex_lb_target_group.web_tg.id]

    healthcheck {
      name = "basic-check"
      http_options {
        port = 80
        path = "/"
      }
    }
  }
}

resource "yandex_lb_http_router" "router" {
  name = "web-router"
}

resource "yandex_lb_virtual_host" "web_host" {
  name           = "vh"
  http_router_id = yandex_lb_http_router.router.id
  route {
    name = "web"
    http_route {
      http_route_action {
        backend_group_id = yandex_lb_backend_group.web_backend.id
      }
    }
  }
  authority = ["*"]
}

resource "yandex_alb_load_balancer" "web_alb" {
  name               = "web-lb"
  network_id         = module.vpc.network_id
  security_group_ids = [yandex_vpc_security_group.web_sg.id]

  allocation_policy {
    location {
      zone_id   = "ru-central1-a"
      subnet_id = module.vpc.subnet_ids[0]
    }
  }

  listener {
    name = "http"
    endpoint {
      address_type = "external"
      ports        = [80]
    }
    http {
      router_id = yandex_lb_http_router.router.id
    }
  }
}

resource "yandex_vpc_security_group" "bastion_sg" {
  name       = "bastion-sg"
  network_id = module.vpc.network_id

  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}
