#!/bin/bash
# NVMe Baseline Benchmark for MSI VenturePro 16 AI
# Run AFTER nvme-diag.sh
set -euo pipefail

RESULTS_FILE="$HOME/nvme-baseline-$(date +%Y%m%d-%H%M%S)-bench.txt"
FIO_FILE="/tmp/fio_nvme_test"

log() {
    echo "$@" | tee -a "$RESULTS_FILE"
}

header() {
    log ""
    log "========================================"
    log "  $1"
    log "========================================"
}

# Check deps
for cmd in ioping fio; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "$cmd not found. Installing..."
        sudo apt install -y "$cmd"
    fi
done

log "NVMe Benchmark Report - $(date)"
log "Governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
log "Saving results to: $RESULTS_FILE"

# ── 1. Latency (ioping) ──────────────────────────────────────────────
header "1. Random Read Latency (ioping, 20 requests)"
ioping -c 20 / 2>&1 | tee -a "$RESULTS_FILE"

# ── 2. 4K Random Read ────────────────────────────────────────────────
header "2. 4K Random Read (10s) - simulates desktop/browser IO"
fio --name=randread4k \
    --ioengine=libaio \
    --direct=1 \
    --rw=randread \
    --bs=4k \
    --iodepth=32 \
    --numjobs=1 \
    --runtime=10 \
    --time_based \
    --group_reporting \
    --filename="$FIO_FILE" \
    --size=1G 2>&1 | tee -a "$RESULTS_FILE"

# ── 3. 4K Random Write ───────────────────────────────────────────────
header "3. 4K Random Write (10s)"
fio --name=randwrite4k \
    --ioengine=libaio \
    --direct=1 \
    --rw=randwrite \
    --bs=4k \
    --iodepth=32 \
    --numjobs=1 \
    --runtime=10 \
    --time_based \
    --group_reporting \
    --filename="$FIO_FILE" \
    --size=1G 2>&1 | tee -a "$RESULTS_FILE"

# ── 4. Sequential Read ───────────────────────────────────────────────
header "4. Sequential Read 1M (10s)"
fio --name=seqread \
    --ioengine=libaio \
    --direct=1 \
    --rw=read \
    --bs=1M \
    --iodepth=16 \
    --numjobs=1 \
    --runtime=10 \
    --time_based \
    --group_reporting \
    --filename="$FIO_FILE" \
    --size=1G 2>&1 | tee -a "$RESULTS_FILE"

# ── 5. Sequential Write ──────────────────────────────────────────────
header "5. Sequential Write 1M (10s)"
fio --name=seqwrite \
    --ioengine=libaio \
    --direct=1 \
    --rw=write \
    --bs=1M \
    --iodepth=16 \
    --numjobs=1 \
    --runtime=10 \
    --time_based \
    --group_reporting \
    --filename="$FIO_FILE" \
    --size=1G 2>&1 | tee -a "$RESULTS_FILE"

# ── 6. Mixed Random R/W (70/30) ──────────────────────────────────────
header "6. Mixed 4K Random 70% Read / 30% Write (10s)"
fio --name=mixed \
    --ioengine=libaio \
    --direct=1 \
    --rw=randrw \
    --rwmixread=70 \
    --bs=4k \
    --iodepth=32 \
    --numjobs=1 \
    --runtime=10 \
    --time_based \
    --group_reporting \
    --filename="$FIO_FILE" \
    --size=1G 2>&1 | tee -a "$RESULTS_FILE"

# ── 7. Low-depth latency test ────────────────────────────────────────
header "7. 4K Random Read QD=1 (pure latency test, 10s)"
fio --name=latency \
    --ioengine=libaio \
    --direct=1 \
    --rw=randread \
    --bs=4k \
    --iodepth=1 \
    --numjobs=1 \
    --runtime=10 \
    --time_based \
    --group_reporting \
    --filename="$FIO_FILE" \
    --size=1G 2>&1 | tee -a "$RESULTS_FILE"

# Cleanup
rm -f "$FIO_FILE"

header "DONE"
log "Results saved to: $RESULTS_FILE"
log ""
log "Expected ranges for Phison PS5027-E27T PCIe4 (DRAM-less):"
log "  4K random read QD32:  ~80-120K IOPS"
log "  4K random write QD32: ~200-400K IOPS"
log "  Sequential read:      ~4000-5000 MB/s"
log "  Sequential write:     ~3500-4500 MB/s"
log "  4K QD1 latency:       ~50-80 us"
log ""
log "If your numbers are significantly below these, the VMD"
log "overhead or another issue is degrading performance."
