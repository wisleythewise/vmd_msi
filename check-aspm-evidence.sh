#!/bin/bash
# Check if ASPM is causing NVMe issues - evidence collector
set -euo pipefail

echo "========================================"
echo "  ASPM Issue Evidence Report"
echo "  $(date)"
echo "========================================"

echo ""
echo "=== 1. Is ASPM L1 enabled on NVMe link? ==="
lspci -vvv -s 10000:e1:00.0 2>/dev/null | grep -i "lnkctl\|aspm\|L1" || echo "(could not read)"

echo ""
echo "=== 2. Is ASPM L1 enabled on upstream bridge (VMD port)? ==="
lspci -vvv -s 10000:e0:06.1 2>/dev/null | grep -i "lnkctl\|aspm\|L1" || echo "(could not read)"

echo ""
echo "=== 3. L1 substates (L1.1 / L1.2 -- deeper sleep)? ==="
lspci -vvv -s 10000:e1:00.0 2>/dev/null | grep -i "L1Sub\|L1\.1\|L1\.2\|L1PM" || echo "(none found)"
lspci -vvv -s 10000:e0:06.1 2>/dev/null | grep -i "L1Sub\|L1\.1\|L1\.2\|L1PM" || echo "(none found)"

echo ""
echo "=== 4. Current ASPM policy ==="
cat /sys/module/pcie_aspm/parameters/policy 2>/dev/null || echo "(not available)"

echo ""
echo "=== 5. NVMe IO timeouts (the stalls you feel) ==="
TIMEOUTS=$(dmesg | grep -c "nvme.*timeout" 2>/dev/null || echo 0)
echo "Total timeout events this boot: $TIMEOUTS"
dmesg | grep "nvme.*timeout" 2>/dev/null | head -10
if [ "$TIMEOUTS" -gt 10 ]; then
    echo "... ($TIMEOUTS total, showing first 10)"
fi

echo ""
echo "=== 6. Timeouts clustered after idle? ==="
echo "(gaps between timestamps suggest link went to sleep during idle)"
dmesg | grep "nvme.*timeout" 2>/dev/null | awk -F'[][]' '{print $2}' | awk '{
    if (prev != "") {
        gap = $1 - prev
        if (gap > 60) printf "  %.0fs gap before next timeout (link had time to enter L1)\n", gap
        else printf "  %.1fs gap (burst - link still waking)\n", gap
    }
    prev = $1
}'

echo ""
echo "=== 7. PCIe AER errors (link problems) ==="
AER=$(dmesg | grep -i "aer.*error\|aer.*correct\|pcie.*error" 2>/dev/null | grep -v "enabled" | head -10)
if [ -n "$AER" ]; then
    echo "$AER"
else
    echo "(none found)"
fi

echo ""
echo "=== 8. PCIe link retraining / down / up ==="
LINK=$(dmesg | grep -i "link.*down\|link.*up\|retrain\|link.*speed\|bandwidth" 2>/dev/null | head -10)
if [ -n "$LINK" ]; then
    echo "$LINK"
else
    echo "(none found)"
fi

echo ""
echo "=== 9. Power source (worse on battery?) ==="
for f in /sys/class/power_supply/*/type; do
    dir=$(dirname "$f")
    name=$(basename "$dir")
    type=$(cat "$f" 2>/dev/null)
    status=$(cat "$dir/status" 2>/dev/null || echo "n/a")
    echo "  $name: type=$type status=$status"
done

echo ""
echo "=== 10. System uptime & when timeouts started ==="
echo "Uptime: $(uptime -p)"
FIRST=$(dmesg | grep "nvme.*timeout" 2>/dev/null | head -1 | awk -F'[][]' '{print $2}' | awk '{printf "%.0f", $1}')
if [ -n "$FIRST" ]; then
    echo "First timeout at: ${FIRST}s after boot"
else
    echo "No timeouts found"
fi

echo ""
echo "========================================"
echo "  VERDICT"
echo "========================================"

if [ "$TIMEOUTS" -gt 0 ]; then
    echo ""
    echo "ASPM L1 is ENABLED and you have $TIMEOUTS IO timeouts."
    echo "The timeouts say 'completion polled' which means:"
    echo "  - NVMe hardware completed the IO (data is ready)"
    echo "  - The interrupt to notify the CPU never arrived"
    echo "  - The driver had to manually check after timeout"
    echo ""
    echo "This is the classic ASPM L1 + VMD interrupt delivery failure."
    echo "pcie_aspm=off should fix it."
else
    echo ""
    echo "No timeouts found. If system feels fine, ASPM may not be"
    echo "the issue (or it was already fixed)."
fi
