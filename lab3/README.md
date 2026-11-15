\# Лабораторная работа №3 — Ansible



\## Описание



Автоматизированное развёртывание веб-приложения Spring Boot с использованием Ansible и Docker Compose.



Ansible устанавливает и настраивает Nginx, устанавливает Java 21, развёртывает Spring Boot приложение и запускает его с помощью shell-скрипта.



\## Используемые технологии



\- Docker и Docker Compose

\- Ansible

\- Ubuntu 24.04

\- Nginx

\- Java 21

\- Spring Boot 3.5.7

\- Maven

\- SSH



\## Архитектура



Используются три Docker-контейнера, объединённые одной сетью `lab3-network`.



| Контейнер | Назначение |

|---|---|

| ansible-master | Управление целевыми серверами через Ansible |

| nginx-server | Reverse proxy для приложения |

| app-server | Запуск Spring Boot приложения |



Схема взаимодействия:



```text

&#x20;             Пользователь

&#x20;                  |

&#x20;            localhost:8080

&#x20;                  |

&#x20;            nginx-server

&#x20;               порт 80

&#x20;                  |

&#x20;             app-server

&#x20;              порт 8080



ansible-master --SSH--> nginx-server

&#x20;      |

&#x20;      +----------SSH--> app-server

```



\## Структура проекта



```text

lab3/

├── docker-compose.yml

├── README.md

├── ansible/

│   ├── inventory.ini

│   ├── playbook.yml

│   └── roles/

│       ├── nginx/

│       │   ├── tasks/main.yml

│       │   ├── templates/app.conf.j2

│       │   └── handlers/main.yml

│       └── app/

│           ├── tasks/main.yml

│           └── files/start.sh

├── docker/

│   ├── master/Dockerfile

│   └── target/Dockerfile

├── ssh/

├── scripts/

└── docs/

&#x20;   └── screenshots/

```



Исходный код Spring Boot приложения находится в `lab2/app/`.



\## Требования



Для запуска необходимы:



\- Docker Desktop с поддержкой Docker Compose

\- Git

\- Доступ к интернету для установки зависимостей

\- Исходный код приложения из `lab2/app/`



Все команды ниже выполняются из корня репозитория `linux-labs`.



\## Подготовка



\### 1. Сборка приложения



Перейти в каталог приложения:



```cmd

cd lab2\\app

```



Собрать приложение с помощью Maven:



```cmd

mvn clean package -DskipTests

```



После сборки должен появиться файл:



```text

lab2/app/target/app.jar

```



Вернуться в корень репозитория:



```cmd

cd ..\\..

```



\### 2. Подготовка SSH-ключей



Для подключения Ansible к контейнерам используется SSH-ключ ED25519.



Если ключи отсутствуют, создать их:



```cmd

ssh-keygen -t ed25519 -f lab3\\ssh\\id\_ed25519 -N ""

```



Приватный ключ `id\_ed25519` не должен попадать в Git.



\### 3. Запуск контейнеров



```cmd

docker compose -f lab3\\docker-compose.yml up -d --build

```



Проверить состояние:



```cmd

docker compose -f lab3\\docker-compose.yml ps

```



Должны быть запущены три контейнера:



\- lab3-ansible-master

\- lab3-nginx-server

\- lab3-app-server



\## Запуск Ansible



\### Проверка SSH-подключений



```cmd

docker compose -f lab3\\docker-compose.yml exec ansible-master ansible all -i inventory.ini -m ping

```



Оба целевых сервера должны вернуть `SUCCESS` и `pong`.



\### Проверка синтаксиса Playbook



```cmd

docker compose -f lab3\\docker-compose.yml exec ansible-master ansible-playbook -i inventory.ini playbook.yml --syntax-check

```



\### Развёртывание



```cmd

docker compose -f lab3\\docker-compose.yml exec ansible-master ansible-playbook -i inventory.ini playbook.yml

```



Playbook содержит две роли.



\*\*Роль nginx:\*\*



\- Устанавливает Nginx

\- Настраивает reverse proxy

\- Проверяет конфигурацию

\- Запускает Nginx



\*\*Роль app:\*\*



\- Проверяет операционную систему

\- Устанавливает Java 21 и необходимые инструменты

\- Создаёт каталог приложения

\- Копирует JAR-файл

\- Развёртывает shell-скрипт запуска

\- Запускает Spring Boot



\## Проверка работоспособности



\### Проверка приложения внутри контейнера



```cmd

docker compose -f lab3\\docker-compose.yml exec app-server curl -i http://localhost:8080/health

```



Ожидаемый ответ:



```json

{"status":"UP"}

```



\### Проверка через Nginx



```cmd

curl -i http://localhost:8080/health

```



Ожидаемый результат:



```text

HTTP/1.1 200

Server: nginx/1.24.0 (Ubuntu)

Content-Type: application/json



{"status":"UP"}

```



Это подтверждает, что Nginx перенаправляет HTTP-запросы к Spring Boot приложению.



\### Проверка повторного запуска Ansible



Повторно выполнить:



```cmd

docker compose -f lab3\\docker-compose.yml exec ansible-master ansible-playbook -i inventory.ini playbook.yml

```



Повторное выполнение должно завершаться без ошибок. Уже установленные пакеты и неизменённые конфигурации не должны устанавливаться повторно.



\## Скриншоты



Скриншоты результатов находятся в `lab3/docs/screenshots/`.



\## Остановка контейнеров



```cmd

docker compose -f lab3\\docker-compose.yml down

```



\## Результат



В ходе лабораторной работы реализовано автоматизированное развёртывание приложения с использованием двух Ansible-ролей.



Проверена работоспособность Spring Boot приложения через Nginx reverse proxy. Все три контейнера успешно запускаются в общей Docker-сети.

