#!/usr/bin/env sh
set -eu

src="${HOME}/.config/sddm"
theme="last-of-us"

sudo install -d /etc/sddm.conf.d
sudo install -m 0644 "${src}/conf.d/10-theme.conf" /etc/sddm.conf.d/10-theme.conf
sudo install -m 0644 "${src}/conf.d/20-session.conf" /etc/sddm.conf.d/20-session.conf

sudo install -d "/usr/share/sddm/themes/${theme}"
sudo cp -a "${src}/themes/${theme}/." "/usr/share/sddm/themes/${theme}/"
sudo chown -R root:root "/usr/share/sddm/themes/${theme}"
sudo find "/usr/share/sddm/themes/${theme}" -type d -exec chmod 0755 {} +
sudo find "/usr/share/sddm/themes/${theme}" -type f -exec chmod 0644 {} +
