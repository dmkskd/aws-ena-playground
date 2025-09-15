#!/bin/bash

# AWS Nitro System Detection Script
# Run this on an EC2 instance to check if it's Nitro-based

echo "========================================="
echo "    AWS Nitro System Detection"
echo "========================================="
echo

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    local status=$1
    local message=$2
    if [ "$status" = "PASS" ]; then
        echo -e "✅ ${GREEN}PASS${NC}: $message"
    elif [ "$status" = "FAIL" ]; then
        echo -e "❌ ${RED}FAIL${NC}: $message"
    else
        echo -e "ℹ️  ${YELLOW}INFO${NC}: $message"
    fi
}

# Check 1: Instance metadata
echo "🔍 Checking instance metadata..."
echo "   Command: curl -s --max-time 3 http://169.254.169.254/latest/meta-data/instance-type"
INSTANCE_TYPE=$(curl -s --max-time 3 http://169.254.169.254/latest/meta-data/instance-type 2>/dev/null)
CURL_EXIT_CODE=$?
if [ $CURL_EXIT_CODE -eq 0 ] && [ -n "$INSTANCE_TYPE" ]; then
    print_status "INFO" "Instance Type: $INSTANCE_TYPE"
else
    print_status "FAIL" "Cannot retrieve instance metadata"
    if [ $CURL_EXIT_CODE -eq 28 ]; then
        echo "   💡 Timeout - metadata service may be restricted"
    elif [ $CURL_EXIT_CODE -eq 7 ]; then
        echo "   💡 Connection failed - check network connectivity"
    elif [ $CURL_EXIT_CODE -eq 0 ] && [ -z "$INSTANCE_TYPE" ]; then
        echo "   💡 Empty response - metadata service returned no data"
    else
        echo "   💡 curl exit code: $CURL_EXIT_CODE"
    fi
    
    # Try alternative metadata endpoints
    echo "   🔄 Trying alternative metadata checks..."
    if curl -s --max-time 2 http://169.254.169.254/latest/meta-data/ >/dev/null 2>&1; then
        echo "   💡 Metadata service is reachable but instance-type endpoint failed"
    else
        echo "   💡 Metadata service appears to be blocked or unavailable"
    fi
fi
echo

# Check 2: System manufacturer
echo "🔍 Checking system manufacturer..."
echo "   Command: sudo dmidecode -s system-manufacturer"
if command -v dmidecode >/dev/null 2>&1; then
    MANUFACTURER=$(sudo dmidecode -s system-manufacturer 2>/dev/null | head -1)
    if [[ "$MANUFACTURER" == *"Amazon EC2"* ]]; then
        print_status "PASS" "System Manufacturer: $MANUFACTURER (Nitro)"
    else
        print_status "FAIL" "System Manufacturer: $MANUFACTURER (Not Nitro)"
    fi
else
    print_status "FAIL" "dmidecode not available - install for complete system check"
    echo "   💡 Install with: sudo yum install dmidecode -y"
    echo "   💡 This tool provides definitive hypervisor identification"
fi
echo

# Check 3: ENA Network Driver
echo "🔍 Checking network driver..."
echo "   Command: ls /sys/class/net/ | grep -E '^(eth|ens|enp)' + readlink driver paths"
ENA_FOUND=false
for iface in $(ls /sys/class/net/ | grep -E '^(eth|ens|enp)'); do
    if [ -f "/sys/class/net/$iface/device/driver/module" ]; then
        DRIVER=$(basename $(readlink /sys/class/net/$iface/device/driver) 2>/dev/null)
        if [ "$DRIVER" = "ena" ]; then
            print_status "PASS" "Interface $iface uses ENA driver (Nitro)"
            ENA_FOUND=true
        fi
    fi
done

# Alternative check using ethtool
if [ "$ENA_FOUND" = false ]; then
    for iface in $(ip link show | grep -E '^[0-9]+:' | cut -d: -f2 | tr -d ' ' | grep -E '^(eth|ens|enp)'); do
        if command -v ethtool >/dev/null 2>&1; then
            DRIVER_INFO=$(ethtool -i $iface 2>/dev/null | grep "^driver:" | awk '{print $2}')
            if [ "$DRIVER_INFO" = "ena" ]; then
                print_status "PASS" "Interface $iface uses ENA driver (Nitro)"
                ENA_FOUND=true
            fi
        fi
    done
fi

if [ "$ENA_FOUND" = false ]; then
    print_status "FAIL" "No ENA network interfaces found"
fi
echo

# Check 4: NVMe storage (Nitro uses NVMe for EBS)
echo "🔍 Checking storage type..."
echo "   Command: lsblk | grep nvme"
if lsblk | grep -q nvme; then
    NVME_COUNT=$(lsblk | grep -c nvme)
    print_status "PASS" "Found $NVME_COUNT NVMe device(s) (Nitro)"
else
    print_status "FAIL" "No NVMe devices found (likely Xen)"
fi
echo

# Check 5: PCI devices
echo "🔍 Checking PCI devices..."
echo "   Command: lspci | grep -i Amazon.com"
if lspci | grep -qi "Amazon.com"; then
    AMAZON_DEVICES=$(lspci | grep -i "Amazon.com" | wc -l)
    print_status "PASS" "Found $AMAZON_DEVICES Amazon PCI device(s) (Nitro)"
    echo "   Devices:"
    lspci | grep -i "Amazon.com" | sed 's/^/   - /'
else
    print_status "FAIL" "No Amazon PCI devices found"
fi
echo

# Check 6: SR-IOV support
echo "🔍 Checking SR-IOV support..."
echo "   Command: lspci -v | grep -i 'single root'"
if lspci -v 2>/dev/null | grep -qi "single root"; then
    print_status "PASS" "SR-IOV support detected (Nitro feature)"
else
    print_status "INFO" "SR-IOV not detected or not visible"
fi
echo

# Final verdict
echo "========================================="
echo "           FINAL VERDICT"
echo "========================================="

NITRO_INDICATORS=0
[ "$ENA_FOUND" = true ] && ((NITRO_INDICATORS++))
[ "$(lsblk | grep -c nvme)" -gt 0 ] && ((NITRO_INDICATORS++))
[ "$(lspci | grep -ci "Amazon.com")" -gt 0 ] && ((NITRO_INDICATORS++))

if [ $NITRO_INDICATORS -ge 2 ]; then
    echo -e "🎉 ${GREEN}This instance is NITRO-based!${NC}"
    echo "   ✅ Ready for ENA driver development"
else
    echo -e "⚠️  ${RED}This instance appears to be XEN-based${NC}"
    echo "   ❌ Limited ENA support"
fi

echo
echo "Nitro indicators found: $NITRO_INDICATORS/3"
echo "========================================="