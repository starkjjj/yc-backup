# yc-backup
test stand for YC backup whith terraform
## Terraform
Описывается два ресурса:
- yandex_backup_policy (Основная настройка политики бэкапов)
- yandex_backup_policy_bindings (Биндинг к инстасну)
- Сервис аккаунт с правами backup_editor (Должен быть прикреплен к ВМ)

Также обязатльно создание security_goup по офицальной доке 
## Особенности
- Данные хрнаяться только в сервисном бакете (то есть свой бакет под бэкап создать нельзя) (сделано из-за сложности структуры хранения и безопасности)
- Работает по средствоми агента (Для установки curl https://storage.yandexcloud.net/backup-distributions/agent_installer.sh | sudo bash)
- Восстанавлить данные можно только при помощи cloud_backup в яндексе

"Получить доступ к файлам копий и бакетам, в которых они хранятся, нельзя. Восстановить ВМ или сервер BareMetal из копии можно только средствами Cloud Backup."
- В файлах terrafrom написаны комментарии на основыне параметры 
## Как добавить к существуещему интаснсу
- https://yandex.cloud/ru/docs/backup/operations/connect-vm-linux#tf_1
