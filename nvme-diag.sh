#!/bin/bash
# NVMe Diagnostic & Baseline Script for MSI VenturePro 16 AI
# Phison PS5027-E27T + VMD investigation
set -euo pipefail

RESULTS_FILE="$HOME/nvme-baseline-$(date +%Y%m%d-%H%M%S).txt"

log() {
    echo "$@" | tee -a "$RESULTS_FILE"
}

header() {
    log ""
    log "========================================"
    log "  $1"
    log "========================================"
}

log "NVMe Diagnostic Report - $(date)"
log "Saving results to: $RESULTS_FILE"

# ── 1. Fix CPU Governor ──────────────────────────────────────────────
header "1. CPU Governor → performance"
for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo performance | sudo tee "$gov" > /dev/null
done
log "Governor set to: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"

# ── 2. System Info ───────────────────────────────────────────────────
header "2. System Info"
log "Kernel: $(uname -r)"
log "Model: $(cat /sys/class/dmi/id/product_name 2>/dev/null)"
log "BIOS: $(cat /sys/class/dmi/id/bios_version 2>/dev/null)"
log "NVMe model: $(cat /sys/class/nvme/nvme0/model 2>/dev/null)"
log "NVMe FW: $(cat /sys/class/nvme/nvme0/firmware_rev 2>/dev/null)"
log "NVMe state: $(cat /sys/class/nvme/nvme0/state 2>/dev/null)"
log "IO scheduler: $(cat /sys/block/nvme0n1/queue/scheduler 2>/dev/null)"
log "ASPM policy: $(cat /sys/module/pcie_aspm/parameters/policy 2>/dev/null)"
log "Cmdline: $(cat /proc/cmdline)"

# ── 3. dmesg Errors ──────────────────────────────────────────────────
header "3. dmesg - NVMe Errors"
sudo dmesg | grep -i "nvme.*timeout\|nvme.*reset\|nvme.*error\|nvme.*fail\|CSTS=\|nvme.*warn" | tail -30 | tee -a "$RESULTS_FILE" || log "(none found)"

header "3b. dmesg - PCIe / AER Errors"
sudo dmesg | grep -i "aer\|pcie.*error\|corrected\|uncorrectable" | tail -20 | tee -a "$RESULTS_FILE" || log "(none found)"

header "3c. dmesg - Thermal / Throttling"
sudo dmesg | grep -i "throttl\|thermal" | tail -10 | tee -a "$RESULTS_FILE" || log "(none found)"

header "3d. dmesg - All NVMe messages"
sudo dmesg | grep -i nvme | tail -30 | tee -a "$RESULTS_FILE" || log "(none found)"

# ── 4. NVMe SMART Health ─────────────────────────────────────────────
header "4. NVMe SMART Health"
if command -v nvme &>/dev/null; then
    sudo nvme smart-log /dev/nvme0 2>&1 | tee -a "$RESULTS_FILE"
else
    log "nvme-cli not installed. Install with: sudo apt install nvme-cli"
fi

# ── 5. Interrupt Status ──────────────────────────────────────────────
header "5. VMD & NVMe Interrupt Counts"
grep -E "vmd|nvme" /proc/interrupts | tee -a "$RESULTS_FILE"

# ── 6. PCIe Link Status ──────────────────────────────────────────────
header "6. PCIe Link Status (NVMe)"
sudo lspci -vvv -s 10000:e1:00.0 2>/dev/null | grep -iE "LnkCap:|LnkSta:|LnkCtl:|Speed|Width" | tee -a "$RESULTS_FILE" || log "(needs sudo/lspci)"

log ""
log "Diagnostics complete. Now running benchmarks..."
