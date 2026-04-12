#!/bin/bash

# Определяем имя обычного пользователя, который запустил скрипт
# Если скрипт запущен через pkexec, переменная $SUDO_USER будет пустой,
# поэтому используем логин из окружения.
REAL_USER="${SUDO_USER:-$USER}"

# Запускаем root-часть через pkexec
pkexec bash -c "
    set -e

    echo -e  '\e[33m
    Обновление системы и установка доп пакетов.
    \e[0m'

    apt-get update -y
    apt-get dist-upgrade -y

    apt-get -y install sudo synaptic-usermode epmgpi eepm-play-gui gearlever android-tools pipewire-jack spruce git skanlite flatpak flatpak-repo-flathub firsttime-flatpak-mask-openh264 flatpak-kcm plasma-discover-flatpak print-manager sane-airscan airsane gnome-disk-utility icon-theme-Papirus xdg-desktop-portal-gtk net-snmp kcm-grub2 kaccounts-providers avahi-daemon avahi-tools ffmpegthumbnailer mediainfo samba-usershares kdeconnect kamoso kio-admin

    echo 'Включаю wheel для sudo...'
    control sudowheel enabled

    echo 'Добавляю пользователя $REAL_USER в группу wheel,dialout,lp'
    usermod -aG wheel '$REAL_USER'
    usermod -a -G dialout '$REAL_USER'
    usermod -a -G lp '$REAL_USER'

    echo 'Root-часть выполнена.'
"
#==========================================================


echo -e  '\e[33m
Обновление программ в epm play.

Необходимо ввести пароль еще раз:
\e[0m'

sudo epm upgrade "https://download.etersoft.ru/pub/Korinf/x86_64/ALTLinux/p11/eepm-*.noarch.rpm"

echo -e  '\e[33m
Готово.
\e[0m'

#==========================================================

echo -e  '\e[33m
Разрешение приложениям Flatpak на доступ к домашнему каталогу
\e[0m'
flatpak override --user --filesystem=home
echo 'готово, теперь drag-n-drop с рабочего стола работает.
'

#==========================================================

echo -e  '\e[33m
Настройка адекватного поведения индикатора копирования файлов
\e[0m'
DIRTY_FILE="/etc/sysctl.d/90-dirty.conf"

echo "→ Applying and saving vm.dirty settings..."

# 64 МБ и 16 МБ
DIRTY_BYTES=$((64 * 1024 * 1024))
DIRTY_BG_BYTES=$((16 * 1024 * 1024))

echo "→ Writing persistent config to $DIRTY_FILE"
sudo bash -c "cat > $DIRTY_FILE" <<EOF
vm.dirty_bytes = $DIRTY_BYTES
vm.dirty_background_bytes = $DIRTY_BG_BYTES
EOF

echo "→ Applying values now..."
sudo sysctl -p "$DIRTY_FILE"

echo "✓ Done. Persistent settings active!"
echo "
Check after reboot:"
echo " sudo sysctl vm.dirty_bytes vm.dirty_background_bytes

Готово.
"

#===========================================================

echo -e  '\e[33m
Включение возможности загрузки настроек из интернета
\e[0m'

sudo sed -i 's/ghns=false/ghns=true/g' /etc/kf5/xdg/kdeglobals
sudo sed -i 's/ghns=false/ghns=true/g' /etc/xdg/kdeglobals

echo '
Готово.'

#===========================================================


echo -e  '\e[33m
Создание thumbnailer для .FCstd файлов.
\e[0m'

echo 'Удаление старых файлов'
sudo rm -f /usr/local/bin/fcstd-thumbnailer
sudo rm -f /usr/share/thumbnailers/fcstd.thumbnailer
echo '
Создание файла /usr/local/bin/freecad-thumbnailer'
sudo tee /usr/local/bin/freecad-thumbnailer > /dev/null << 'EOF'
#!/bin/bash

INPUT="$3"
OUTPUT="$4"

# проверка наличия thumbnail внутри архива
if unzip -l "$INPUT" thumbnails/Thumbnail.png >/dev/null 2>&1; then
    unzip -p "$INPUT" thumbnails/Thumbnail.png > "$OUTPUT"
    exit 0
else
    # важно: не создавать OUTPUT
    exit 1
fi
EOF

sudo chmod +x /usr/local/bin/freecad-thumbnailer

echo '
Создание файла /usr/share/thumbnailers/FreeCAD1.thumbnailer'
sudo tee /usr/share/thumbnailers/FreeCAD1.thumbnailer > /dev/null << 'EOF'
[Thumbnailer Entry]
TryExec=freecad-thumbnailer
Exec=freecad-thumbnailer -s %s %i %o
MimeType=application/x-extension-fcstd;
EOF

echo '
Готово.'

#===========================================================

echo -e  '\e[33m
Создание thumbnailer для .dwg файлов.
\e[0m'

set -e

# 1. Скачивание архива
echo 'Скачиваем NConvert
'
cd /tmp
wget https://download.xnview.com/NConvert-linux64.tgz -O NConvert-linux64.tgz

# 2. Распаковка в /usr/local
#sudo rm -rf /usr/local/NConvert
sudo tar -xzf NConvert-linux64.tgz -C /usr/local
#sudo mv /usr/local/NConvert-linux64 /usr/local/NConvert

# 3. Симлинк в /usr/local/bin
sudo rm -f /usr/local/bin/nconvert
sudo ln -s /usr/local/NConvert/nconvert /usr/local/bin/nconvert

# 4. Скрипт dwg-thumbnail.sh
echo 'Создаем /usr/local/bin/dwg-thumbnail.sh
'
sudo tee /usr/local/bin/dwg-thumbnail.sh >/dev/null <<'EOF'
#!/bin/bash
INPUT="$1"
OUTPUT="$2"
SIZE="$3"

NCONVERT="/usr/local/bin/nconvert"

# Создаём директорию для результата
mkdir -p "$(dirname "$OUTPUT")"

# Создаём временный файл с расширением .dwg
TMP="/tmp/dwgthumb-$$.dwg"
cp "$INPUT" "$TMP"

# Генерация PNG
"$NCONVERT" -quiet -out png -resize "$SIZE" "$SIZE" -o "$OUTPUT" "$TMP"

rm -f "$TMP"
EOF

sudo chmod +x /usr/local/bin/dwg-thumbnail.sh

# 5. Файл dwg.thumbnailer
echo 'Создаем /usr/share/thumbnailers/dwg.thumbnailer
'
sudo tee /usr/share/thumbnailers/dwg.thumbnailer >/dev/null <<'EOF'
[Thumbnailer Entry]
TryExec=/usr/local/bin/dwg-thumbnail.sh
Exec=/usr/local/bin/dwg-thumbnail.sh %i %o %s
MimeType=image/vnd.dwg; image/x-dwg; application/acad;
Flags=NoCopy
EOF

echo '
Готово.'

#===========================================================

echo -e  '\e[33m
Установка f3d через epm play
\e[0m'

sudo epm play -y f3d

echo '
Готово.'

#===========================================================

echo '
Очистка кэша'

rm -rf ~/.cache/thumbnails/*

#===========================================================

echo -e  '\e[33m
Готово.

Для активации превью 3D-файлов зайдите в менеджер файлов Dolphin - три точки -
настройка - настроить Dolphin - вкладка "Миниатюры", там поставьте нужные галочки
на нужных типах файлов, можно на всех.

Теперь желательно перезагрузить компьютер.
\e[0m'






