#!/bin/bash
set -euo pipefail

echo "=== Current GRUB config ==="
grep GRUB_CMDLINE_LINUX_DEFAULT /etc/default/grub

echo ""
echo "=== Creating backup at /etc/default/grub.bak ==="
cp /etc/default/grub /etc/default/grub.bak

echo ""
echo "=== Applying new config ==="
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash nvme_core.default_ps_max_latency_us=0 nvme_core.io_timeout=30 nvme_core.max_retries=10 pcie_aspm=off rd.driver.blacklist=nouveau modprobe.blacklist=nouveau nvidia-drm.modeset=1 rcutree.rcu_idle_gp_delay=1 vt.handoff=7"/' /etc/default/grub

echo ""
echo "=== New GRUB config ==="
grep GRUB_CMDLINE_LINUX_DEFAULT /etc/default/grub

echo ""
echo "=== Creating persistent CPU performance governor ==="
cat > /etc/systemd/system/cpu-performance.service << 'SVCEOF'
[Unit]
Description=Set CPU governor to performance
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo performance > "$g"; done'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SVCEOF
systemctl enable cpu-performance.service

echo ""
echo "=== Running update-grub ==="
update-grub

echo ""
echo "=== Done! Review the config above, then run: sudo reboot ==="
echo "=== To undo: sudo cp /etc/default/grub.bak /etc/default/grub && sudo update-grub ==="
