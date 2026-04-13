#!/bin/bash
# discover-proxy-fix.sh - исправление ошибки Discover после удаления прокси

echo "Исправление Discover (PackageKit)..."

pkexec bash -c '
    echo "Останавливаю packagekit..."
    systemctl stop packagekit
    
    echo "Удаляю базы данных..."
    rm -rf /var/lib/PackageKit /var/cache/PackageKit
    
    echo "Запускаю packagekit..."
    systemctl start packagekit
'

echo "Готово."
