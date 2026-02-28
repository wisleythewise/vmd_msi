#!/bin/bash
set -euo pipefail

echo "=== Current kernel ==="
uname -r

echo ""
echo "=== Finding GRUB menu entry for 6.14.0-37-generic ==="
ENTRY=$(grep -E "menuentry|submenu" /boot/grub/grub.cfg | grep -n "6.14.0-37-generic" | head -1)
echo "Found: $ENTRY"

# Get the submenu ID and menuentry ID for the exact kernel
SUBMENU_ID=$(awk -F"'" '/submenu /{print $4; exit}' /boot/grub/grub.cfg)
ENTRY_ID=$(awk -F"'" "/menuentry.*6.14.0-37-generic[^']* \{/{print \$4; exit}" /boot/grub/grub.cfg)

echo "Submenu ID: $SUBMENU_ID"
echo "Entry ID:   $ENTRY_ID"

GRUB_ID="${SUBMENU_ID}>${ENTRY_ID}"
echo "Full GRUB ID: $GRUB_ID"

echo ""
echo "=== Current GRUB_DEFAULT ==="
grep GRUB_DEFAULT /etc/default/grub

echo ""
echo "=== Backing up /etc/default/grub ==="
cp /etc/default/grub /etc/default/grub.bak2

echo ""
echo "=== Pinning kernel 6.14.0-37-generic as default ==="
sed -i "s/^GRUB_DEFAULT=.*/GRUB_DEFAULT=\"${GRUB_ID}\"/" /etc/default/grub

echo ""
echo "=== New GRUB_DEFAULT ==="
grep GRUB_DEFAULT /etc/default/grub

echo ""
echo "=== Running update-grub ==="
update-grub

echo ""
echo "=========================================="
echo "  Blocking automatic kernel upgrades"
echo "=========================================="
echo ""
echo "=== Holding kernel packages with apt-mark ==="
apt-mark hold linux-image-generic linux-headers-generic linux-generic 2>/dev/null || true
apt-mark hold linux-image-6.14.0-37-generic linux-headers-6.14.0-37-generic linux-modules-6.14.0-37-generic linux-modules-extra-6.14.0-37-generic 2>/dev/null || true

echo ""
echo "=== Currently held packages ==="
apt-mark showhold

echo ""
echo "=== Preventing unattended kernel upgrades ==="
if [ -f /etc/apt/apt.conf.d/50unattended-upgrades ]; then
    if ! grep -q 'Unattended-Upgrade::Package-Blacklist' /etc/apt/apt.conf.d/50unattended-upgrades || ! grep -q 'linux-image' /etc/apt/apt.conf.d/50unattended-upgrades; then
        cp /etc/apt/apt.conf.d/50unattended-upgrades /etc/apt/apt.conf.d/50unattended-upgrades.bak
        cat >> /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'

// Block kernel upgrades (pinned to 6.14.0-37-generic for VMD stability)
Unattended-Upgrade::Package-Blacklist {
    "linux-image-.*";
    "linux-headers-.*";
    "linux-modules-.*";
    "linux-generic";
};
EOF
        echo "Added kernel blacklist to unattended-upgrades config"
    else
        echo "Kernel already in unattended-upgrades blacklist"
    fi
else
    echo "(unattended-upgrades config not found, skipping)"
fi

echo ""
echo "=========================================="
echo "  DONE"
echo "=========================================="
echo ""
echo "1. Kernel 6.14.0-37-generic is now the default boot kernel"
echo "2. Kernel packages are held (apt upgrade will skip them)"
echo "3. Unattended-upgrades will not install new kernels"
echo ""
echo "To undo everything:"
echo "  sudo apt-mark unhold linux-image-generic linux-headers-generic linux-generic"
echo "  sudo apt-mark unhold linux-image-6.14.0-37-generic linux-headers-6.14.0-37-generic linux-modules-6.14.0-37-generic linux-modules-extra-6.14.0-37-generic"
echo "  sudo cp /etc/default/grub.bak2 /etc/default/grub && sudo update-grub"
echo "  sudo cp /etc/apt/apt.conf.d/50unattended-upgrades.bak /etc/apt/apt.conf.d/50unattended-upgrades"
