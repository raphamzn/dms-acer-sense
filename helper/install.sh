#!/bin/sh
# Installs the privileged helper for the Acer Sense DMS plugin.
# Run as root from the plugin's helper/ directory:  sudo sh install.sh
set -eu

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if [ "$(id -u)" -ne 0 ]; then
    echo "rode com sudo: sudo sh $0" >&2
    exit 1
fi

# Usuário que vai receber o NOPASSWD (quem chamou o sudo).
USER_NAME="${SUDO_USER:-$(logname 2>/dev/null || true)}"
if [ -z "$USER_NAME" ] || [ "$USER_NAME" = "root" ]; then
    echo "não consegui detectar o usuário não-root (defina SUDO_USER). Ex: sudo sh $0" >&2
    exit 1
fi

# 1) helper root-owned
install -o root -g root -m 0755 "$DIR/acer-ctl" /usr/local/bin/acer-ctl

# 2) regra sudoers gerada pro usuário, validada ANTES de entrar em /etc/sudoers.d
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
printf '%s ALL=(root) NOPASSWD: /usr/local/bin/acer-ctl\n' "$USER_NAME" > "$TMP"
visudo -cf "$TMP"
install -o root -g root -m 0440 "$TMP" /etc/sudoers.d/acer-ctl
visudo -cf /etc/sudoers.d/acer-ctl

# 3) migração: remove o helper antigo do plugin nitroPanel, se existir
rm -f /usr/local/bin/nitro-ctl /etc/sudoers.d/nitro-ctl

echo "acer-ctl instalado em /usr/local/bin/acer-ctl + /etc/sudoers.d/acer-ctl (usuário: $USER_NAME)"
