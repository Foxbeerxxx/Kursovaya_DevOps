# logging.tf — инфраструктура под Elasticsearch, Kibana и Filebeat

resource "yandex_vpc_security_group" "logging_sg" {
  name       = "logging-sg"
  network_id = module.vpc.network_id

  ingress {
    description       = "Allow SSH from bastion"
    protocol          = "TCP"
    port              = 22
    security_group_id = yandex_vpc_security_group.bastion_sg.id
  }

  ingress {
    description    = "Allow Elasticsearch HTTP"
    protocol       = "TCP"
    port           = 9200
    v4_cidr_blocks = ["10.10.0.0/16"]
  }

  ingress {
    description    = "Allow Kibana Web"
    protocol       = "TCP"
    port           = 5601
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_compute_instance" "elasticsearch" {
  name        = "elasticsearch"
  hostname    = "elasticsearch"
  zone        = "ru-central1-a"
  platform_id = "standard-v1"

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = "fd8q1vfvqgb9g26r8j5o"
      size     = 20
    }
  }

  network_interface {
    subnet_id          = module.vpc.subnet_ids[1]
    nat                = false
    security_group_ids = [yandex_vpc_security_group.logging_sg.id]
  }

  metadata = {
    user-data = file("cloud-init-elasticsearch.yml")
  }
}

resource "yandex_compute_instance" "kibana" {
  name        = "kibana"
  hostname    = "kibana"
  zone        = "ru-central1-b"
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
    security_group_ids = [yandex_vpc_security_group.logging_sg.id]
  }

  metadata = {
    user-data = file("cloud-init-kibana.yml")
  }
}
