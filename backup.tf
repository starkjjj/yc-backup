
# Тестовый интанс для бэкапа
resource "yandex_compute_instance" "test-backup-instance" {
  name = "srv-for-backup"
  resources {
    cores = 2
    memory = 2
  }
  boot_disk {
    disk_id = yandex_compute_disk.srv-for-backup-disk.id
  }

  network_interface {
    subnet_id = "e2lkbvi8emjfdcdcgs4u"
    security_group_ids = [yandex_vpc_security_group.test_backup_security_group.id]
    nat                = true
  }
 
  service_account_id = yandex_iam_service_account.test_sa.id
  metadata = {
    # user-data = "#cloud-config\npackages:\n  - curl\n  - perl\n  - jq\nruncmd:\n  - curl https://storage.yandexcloud.net/backup-distributions/agent_installer.sh | sudo bash\n"
    user-data = "${file("./user-data.txt")}"
  }
}

# Диск для тестового интанса
resource "yandex_compute_disk" "srv-for-backup-disk" {
  name = "srv-for-backup-disk"
  type = "network-hdd"
  zone = "ru-central1-b"
  size = "20"
  image_id = "fd8gq5886iaaakiqhsjn"
}

# Сервис аккаунт для бэкапа

resource "yandex_iam_service_account" "test_sa" {
  name = "sa-backup"
}

# Роль сервсиного аккаунта  
resource "yandex_resourcemanager_folder_iam_member" "test_binding" {
  folder_id = yandex_iam_service_account.test_sa.folder_id
  role      = "backup.editor"
  member    = "serviceAccount:${yandex_iam_service_account.test_sa.id}"
}

# Полная настройка backup policy 
resource "yandex_backup_policy" "my_policy" {
  archive_name                      = "[Machine Name]-[Plan ID]-[Unique ID]a"
  cbt                               = "USE_IF_ENABLED" # Настройки отслеживания изменений блоков
  compression                       = "NORMAL"
  fast_backup_enabled               = true #  Если true, определяет, изменился ли файл, по его размеру и метке времени. В противном случае, всё содержимое файла сравнивается с содержимым, хранящимся в резервной копии.
  format                            = "AUTO"
  multi_volume_snapshotting_enabled = true
  name                              = "backup-policy"
  silent_mode_enabled               = true
  splitting_bytes                   = "9223372036854775807"
  vss_provider                      = "NATIVE"

  reattempts { # Количество повторных попыток, которые следует выполнить при попытке создания резервной копии на хосте
    enabled      = true
    interval     = "1m"
    max_attempts = 10
  }

  retention { # Политика хранения резервных копий
    after_backup = false

    rules {
    #   max_age       = "365d" # Можно поставить max_count = 10 как пример
    #   repeat_period = []
    max_count = 10
    }
  }

  scheduling {
    enabled              = true
    max_parallel_backups = 0
    random_max_delay     = "30m"
    scheme               = "ALWAYS_INCREMENTAL" 
    #scheme (String). Scheme of the backups. 
    #Available values are: ALWAYS_INCREMENTAL, ALWAYS_FULL, WEEKLY_FULL_DAILY_INCREMENTAL, WEEKLY_INCREMENTAL. Default ALWAYS_INCREMENTAL.


    # backup_sets {
    #   execute_by_time { # ИЛИ execute_by_interval
    #     include_last_day_of_month = true
    #     monthdays                 = []
    #     months                    = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
    #     repeat_at                 = ["13:20"] # Список временных интервалов в HH:MM24-часовом формате, когда действует расписание.
    #     repeat_every              = "1h"
    #     type                      = "MONTHLY" # type( Обязательно ) (Строка). Тип планирования. Доступные значения: HOURLY, DAILY, WEEKLY, MONTHLY.
    #     weekdays                  = [] # weekdays(Список строк). Список дней недели, когда будет применена резервная копия. Используется в WEEKLYтипе.
    #   }
    # }
        backup_sets {
        execute_by_time {
        type        = "DAILY"
        repeat_at   = ["9:50"] # Резервные копии создаются по локальному времени ВМ или сервера BareMetal. Возможно небольшое отставание от расписания в зависимости от текущей нагрузки на сервис.

        }
        }
        }

  vm_snapshot_reattempts { #  Количество повторных попыток, которые следует выполнить при попытке создания снимка.
    enabled      = true
    interval     = "1m"
    max_attempts = 10
  }
}

# Секурити группа для общения с cloud backup (обязательна)

# Чтобы агент Cloud Backup мог обмениваться данными с серверами провайдера резервного копирования, для ВМ или сервера BareMetal 
# должен быть обеспечен сетевой доступ к IP-адресам ресурсов сервиса Cloud Backup согласно таблице

resource "yandex_vpc_security_group" "test_backup_security_group" {
  name       = "cloud-backup"
  network_id = "enpml9uf32vi67jdev7e"
   ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "SSH access"
  }
  egress {
    protocol       = "TCP"
    from_port      = 7770
    to_port        = 7800
    v4_cidr_blocks = ["84.47.172.0/24"]
  }
  egress {
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["213.180.204.0/24", "213.180.193.0/24", "178.176.128.0/24", "84.201.181.0/24", "84.47.172.0/24"]
  }
  egress {
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["213.180.204.0/24", "213.180.193.0/24"]
  }
  egress {
    protocol       = "TCP"
    port           = 8443
    v4_cidr_blocks = ["84.47.172.0/24"]
  }
  egress {
    protocol       = "TCP"
    port           = 44445
    v4_cidr_blocks = ["51.250.1.0/24"]
  }
}

# Биндинг к инстансу
resource "yandex_backup_policy_bindings" "binding-test-backup-instance" {
  instance_id = yandex_compute_instance.test-backup-instance.id
  policy_id = yandex_backup_policy.my_policy.id

}

