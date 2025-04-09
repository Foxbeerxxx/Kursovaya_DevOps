# snapshots.tf — резервное копирование дисков всех ВМ

resource "yandex_backup_policy" "daily_snapshots" {
  name = "daily-snapshots"

  schedule_policy {
    expression = "0 3 * * *" # каждый день в 03:00
  }

  retention_period = "168h" # 7 дней

  snapshot_spec {
    description = "Automated snapshot"
    labels = {
      auto_snapshot = "true"
    }
  }

  disk_ids = [
    yandex_compute_instance.web1.boot_disk[0].disk_id,
    yandex_compute_instance.web2.boot_disk[0].disk_id,
    yandex_compute_instance.prometheus.boot_disk[0].disk_id,
    yandex_compute_instance.grafana.boot_disk[0].disk_id,
    yandex_compute_instance.elasticsearch.boot_disk[0].disk_id,
    yandex_compute_instance.kibana.boot_disk[0].disk_id
  ]
}
