# monitoring.tf — разворачивает Prometheus и Grafana

resource "yandex_vpc_security_group" "monitoring_sg" {
  name       = "monitoring-sg"
  network_id = module.vpc.network_id

  ingress {
    description    = "Allow SSH from bastion"
    protocol       = "TCP"
    port           = 22
    security_group_id = yandex_vpc_security_group.bastion_sg.id
  }

  ingress {
    description    = "Prometheus scrape"
    protocol       = "TCP"
    port           = 9100  # Node Exporter
    v4_cidr_blocks = ["10.10.0.0/16"]
  }

  ingress {
    description    = "Nginx log exporter"
    protocol       = "TCP"
    port           = 4040
    v4_cidr_blocks = ["10.10.0.0/16"]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_compute_instance" "prometheus" {
  name        = "prometheus"
  hostname    = "prometheus"
  zone        = "ru-central1-a"
  platform_id = "standard-v1"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd8q1vfvqgb9g26r8j5o"
      size     = 10
    }
  }

  network_interface {
    subnet_id          = module.vpc.subnet_ids[0]
    nat                = false
    security_group_ids = [yandex_vpc_security_group.monitoring_sg.id]
  }

  metadata = {
    user-data = file("cloud-init-prometheus.yml")
  }
}

resource "yandex_compute_instance" "grafana" {
  name        = "grafana"
  hostname    = "grafana"
  zone        = "ru-central1-a"
  platform_id = "standard-v1"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd8q1vfvqgb9g26r8j5o"
      size     = 10
    }
  }

  network_interface {
    subnet_id          = module.vpc.subnet_ids[0]
    nat                = true
    security_group_ids = [yandex_vpc_security_group.monitoring_sg.id]
  }

  metadata = {
    user-data = file("cloud-init-grafana.yml")
  }
}
