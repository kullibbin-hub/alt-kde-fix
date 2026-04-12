#!/bin/bash
sudo systemctl stop packagekit
sudo rm -f /var/lib/PackageKit/transactions.db
sudo systemctl start packagekit
sudo rm -rf ~/.cache/discover
pkcon refresh force
echo "Готово! Discover должен работать."

