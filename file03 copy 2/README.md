# Курсовая работа "DevOps-инженер с нуля" - `Татаринцев Алексей`

## Всю курсовую разобью на части по заданиям

   
---

### Задание 1

1. `сайты`
```
Сайт
Создайте две ВМ в разных зонах, установите на них сервер nginx, если его там нет. ОС и содержимое ВМ должно быть идентичным, это будут наши веб-сервера.

Используйте набор статичных файлов для сайта. Можно переиспользовать сайт из домашнего задания.

Создайте Target Group, включите в неё две созданных ВМ.

Создайте Backend Group, настройте backends на target group, ранее созданную. Настройте healthcheck на корень (/) и порт 80, протокол HTTP.

Создайте HTTP router. Путь укажите — /, backend group — созданную ранее.

Создайте Application load balancer для распределения трафика на веб-сервера, созданные ранее. Укажите HTTP router, созданный ранее, задайте listener тип auto, порт 80.

Протестируйте сайт curl -v <публичный IP балансера>:80
```
2. `Длявыполнение первой задачи потреуется написать несколько файлов первый cloud-init.yml`

```
#cloud-config
users:
  - name: user
    groups: sudo
    shell: /bin/bash
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    ssh_authorized_keys:
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM5m9AhMRWiO+yybLYEHaJhFaODFZDTbOiYqitAxzWgs alexey@dell

packages:
  - nginx

runcmd:
  - echo "<h1>Hello from $(hostname)</h1>" > /var/www/html/index.html
  - systemctl enable nginx
  - systemctl restart nginx



```

3. `Затем main.tf в котором уже прописывается какие  параметры для VM, сеть, группы`

```
# ===== СЕТЬ =====
resource "yandex_vpc_network" "develop" {
  name = "develop-fops-${var.flow}"
}

resource "yandex_vpc_subnet" "develop_a" {
  name           = "develop-fops-${var.flow}-ru-central1-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.develop.id
  v4_cidr_blocks = ["10.0.1.0/24"]
}

resource "yandex_vpc_subnet" "develop_b" {
  name           = "develop-fops-${var.flow}-ru-central1-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.develop.id
  v4_cidr_blocks = ["10.0.2.0/24"]
}

# ===== SECURITY GROUP =====
resource "yandex_vpc_security_group" "web_sg" {
  name       = "web-sg-${var.flow}"
  network_id = yandex_vpc_network.develop.id

  ingress {
    description    = "Allow HTTP"
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "Allow HTTPS"
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "Allow all outbound traffic"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# ===== ОБРАЗ ОС =====
data "yandex_compute_image" "ubuntu_2204_lts" {
  family = "ubuntu-2204-lts"
}

# ===== ВЕБ-СЕРВЕРЫ =====
resource "yandex_compute_instance" "web_a" {
  name        = "web-a"
  hostname    = "web-a"
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

  network_interface {
    subnet_id          = yandex_vpc_subnet.develop_a.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.web_sg.id]
  }
}

resource "yandex_compute_instance" "web_b" {
  name        = "web-b"
  hostname    = "web-b"
  platform_id = "standard-v3"
  zone        = "ru-central1-b"

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

  network_interface {
    subnet_id          = yandex_vpc_subnet.develop_b.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.web_sg.id]
  }
}

# ===== TARGET GROUP для ALB =====
resource "yandex_alb_target_group" "web_tg" {
  name = "web-target-group"

  target {
    ip_address = yandex_compute_instance.web_a.network_interface[0].ip_address
    subnet_id  = yandex_vpc_subnet.develop_a.id
  }

  target {
    ip_address = yandex_compute_instance.web_b.network_interface[0].ip_address
    subnet_id  = yandex_vpc_subnet.develop_b.id
  }
}

# ===== BACKEND GROUP =====
resource "yandex_alb_backend_group" "web_backend_group" {
  name = "web-backend-group"

  http_backend {
    name             = "web-backend"
    weight           = 1
    port             = 80
    target_group_ids = [yandex_alb_target_group.web_tg.id]

    healthcheck {
      timeout  = "1s"
      interval = "1s"
      http_healthcheck {
        path = "/"
      }
    }
  }
}

# ===== HTTP ROUTER =====
resource "yandex_alb_http_router" "web_router" {
  name = "web-router"
}

# ===== VIRTUAL HOST =====
resource "yandex_alb_virtual_host" "web_vhost" {
  name           = "web-vhost"
  http_router_id = yandex_alb_http_router.web_router.id

  route {
    name = "web-route"
    http_route {
      http_route_action {
        backend_group_id = yandex_alb_backend_group.web_backend_group.id
      }
    }
  }
}

# ===== LOAD BALANCER =====
resource "yandex_alb_load_balancer" "web_lb" {
  name       = "web-lb"
  network_id = yandex_vpc_network.develop.id

  allocation_policy {
    location {
      zone_id   = "ru-central1-a"
      subnet_id = yandex_vpc_subnet.develop_a.id
    }
    location {
      zone_id   = "ru-central1-b"
      subnet_id = yandex_vpc_subnet.develop_b.id
    }
  }

  listener {
  name = "web-listener"

  endpoint {
    address {
      external_ipv4_address {}
    }
    ports = [80]
  }

  http {
    handler {
      http_router_id = yandex_alb_http_router.web_router.id
    }
  }
}
}
```


4. `Описываем providers.tf в котором прописан наш ключ авторизации для яндекса и переменные которые присваивают значение моего id облака и рабочей "папки"`

```
terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.129.0"
    }
  }

  required_version = ">=1.8.4"
}

provider "yandex" {
  # token                    = "do not use!!!"
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  service_account_key_file = file("~/authorized_key.json")
}


```

5. `Для работы потребуются переменные заполню в файле variables.tf`

```
variable "flow" {
  type    = string
  default = "24-01"
}

variable "cloud_id" {
  type    = string
  default = "b1gvjpk4qbrvling8qq1"
}
variable "folder_id" {
  type    = string
  default = "b1gse67sen06i8u6ri78"
}

variable "test" {
  type = map(number)
  default = {
    cores         = 2
    memory        = 1
    core_fraction = 20
  }
}


```

6. `Отрабатываю .чтобы проверить и запустить , проделанное. Запускается.`

![5](https://github.com/Foxbeerxxx/Kursovaya_DevOps/blob/main/img/img5.png)`

`ВМ`

![6](https://github.com/Foxbeerxxx/Kursovaya_DevOps/blob/main/img/img6.png)`

`Балансировщик`
![7](https://github.com/Foxbeerxxx/Kursovaya_DevOps/blob/main/img/img7.png)`

`Сеть`
![8](https://github.com/Foxbeerxxx/Kursovaya_DevOps/blob/main/img/img8.png)`

7. `Пробую тестировать сайт curl -v 158.160.144.11:80 и результата нет, выдает ошибку`    

![9](https://github.com/Foxbeerxxx/Kursovaya_DevOps/blob/main/img/img9.png)`




*****************************************************************************************************************



































---

### Задание 2

`Приведите ответ в свободной форме........`

1. `Заполните здесь этапы выполнения, если требуется ....`
2. `Заполните здесь этапы выполнения, если требуется ....`
3. `Заполните здесь этапы выполнения, если требуется ....`
4. `Заполните здесь этапы выполнения, если требуется ....`
5. `Заполните здесь этапы выполнения, если требуется ....`
6. 

```
Поле для вставки кода...
....
....
....
....
```

`При необходимости прикрепитe сюда скриншоты
![Название скриншота 2](ссылка на скриншот 2)`


---

### Задание 3

`Приведите ответ в свободной форме........`

1. `Заполните здесь этапы выполнения, если требуется ....`
2. `Заполните здесь этапы выполнения, если требуется ....`
3. `Заполните здесь этапы выполнения, если требуется ....`
4. `Заполните здесь этапы выполнения, если требуется ....`
5. `Заполните здесь этапы выполнения, если требуется ....`
6. 

```
Поле для вставки кода...
....
....
....
....
```

`При необходимости прикрепитe сюда скриншоты
![Название скриншота](ссылка на скриншот)`

### Задание 4

`Приведите ответ в свободной форме........`

1. `Заполните здесь этапы выполнения, если требуется ....`
2. `Заполните здесь этапы выполнения, если требуется ....`
3. `Заполните здесь этапы выполнения, если требуется ....`
4. `Заполните здесь этапы выполнения, если требуется ....`
5. `Заполните здесь этапы выполнения, если требуется ....`
6. 

```
Поле для вставки кода...
....
....
....
....
```

`При необходимости прикрепитe сюда скриншоты
![Название скриншота](ссылка на скриншот)`
