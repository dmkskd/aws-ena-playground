#!/bin/bash

echo "=========================================="
echo "ENA Custom Driver Binding - Detailed Log"
echo "=========================================="

# Step 1: Initial Status Check
echo -e "\n=== STEP 1: Initial Status Check ==="
echo "Current network interfaces:"
ip link show | grep -E '^[0-9]+:'

echo -e "\nCurrent PCI devices and drivers:"
lspci -k | grep -A 2 "Ethernet controller"

echo -e "\nCurrent driver modules loaded:"
lsmod | grep ena

# Step 2: Identify Target Interface
echo -e "\n=== STEP 2: Identify Target Interface ==="
echo "Finding all ENA interfaces:"
for iface in $(ls /sys/class/net/ | grep -E '^(eth|ens)'); do
    if [ -d "/sys/class/net/$iface/device" ]; then
        driver=$(basename $(readlink /sys/class/net/$iface/device/driver) 2>/dev/null)
        pci_addr=$(basename $(readlink /sys/class/net/$iface/device) 2>/dev/null)
        echo "  $iface -> Driver: $driver -> PCI: $pci_addr"
    fi
done

# Find second interface (not ens5)
SECOND_IFACE=$(ls /sys/class/net/ | grep -E '^(eth|ens)' | grep -v ens5 | head -1)
echo -e "\nTarget interface: $SECOND_IFACE"

if [ -z "$SECOND_IFACE" ]; then
    echo "ERROR: No second interface found!"
    exit 1
fi

# Get PCI address
PCI_ADDR=$(basename $(readlink /sys/class/net/$SECOND_IFACE/device) 2>/dev/null)
echo "Target PCI address: $PCI_ADDR"

# Step 3: Check and Load Custom Driver Module
echo -e "\n=== STEP 3: Check and Load Custom Driver Module ==="
echo "Checking if ena_custom module is loaded:"
if lsmod | grep -q ena_custom; then
    echo "✓ ena_custom module already loaded"
else
    echo "✗ ena_custom module not loaded - attempting to load"
    
    # Check if module file exists
    MODULE_FILE=$(find /lib/modules/$(uname -r) -name "ena_custom.ko" 2>/dev/null | head -1)
    if [ -n "$MODULE_FILE" ]; then
        echo "✓ Module file found: $MODULE_FILE"
    else
        echo "✗ Module file not found!"
        echo "Available ena modules:"
        find /lib/modules/$(uname -r) -name "*ena*" 2>/dev/null
        exit 1
    fi
    
    # Load the module
    sudo modprobe ena_custom
    if [ $? -eq 0 ]; then
        echo "✓ ena_custom module loaded successfully"
    else
        echo "✗ Failed to load ena_custom module"
        echo "Checking dmesg for errors:"
        sudo dmesg | tail -10
        exit 1
    fi
fi

echo -e "\nModule info:"
modinfo ena_custom | head -5

# Step 4: Check Driver Directories
echo -e "\n=== STEP 4: Check Driver Directories ==="
echo "ENA driver directory contents:"
if [ -d "/sys/bus/pci/drivers/ena/" ]; then
    ls -la /sys/bus/pci/drivers/ena/ | head -10
else
    echo "✗ ENA driver directory not found"
fi

echo -e "\nENA_CUSTOM driver directory contents:"
if [ -d "/sys/bus/pci/drivers/ena_custom/" ]; then
    echo "✓ ena_custom driver directory exists"
    ls -la /sys/bus/pci/drivers/ena_custom/ | head -10
else
    echo "✗ ena_custom driver directory not found"
    echo "This indicates the module didn't register properly"
    exit 1
fi

# Step 5: Pre-binding Status
echo -e "\n=== STEP 5: Pre-binding Status ==="
echo "Interface $SECOND_IFACE status:"
ip link show $SECOND_IFACE
echo -e "\nInterface driver info:"
ethtool -i $SECOND_IFACE

# Step 6: Bring Interface Down
echo -e "\n=== STEP 6: Bring Interface Down ==="
echo "Bringing down $SECOND_IFACE..."
sudo ip link set $SECOND_IFACE down
if [ $? -eq 0 ]; then
    echo "✓ Interface brought down successfully"
else
    echo "✗ Failed to bring down interface"
fi

echo "Interface status after bringing down:"
ip link show $SECOND_IFACE

# Step 7: Unbind from ENA Driver
echo -e "\n=== STEP 7: Unbind from ENA Driver ==="
echo "Unbinding $PCI_ADDR from ena driver..."
echo "$PCI_ADDR" | sudo tee /sys/bus/pci/drivers/ena/unbind
UNBIND_RESULT=$?

echo "Unbind result: $UNBIND_RESULT"
sleep 2

echo "Checking if device is unbound:"
if [ -d "/sys/bus/pci/drivers/ena/$PCI_ADDR" ]; then
    echo "✗ Device still bound to ena driver"
else
    echo "✓ Device successfully unbound from ena driver"
fi

echo "Interface status after unbind:"
ip link show 2>/dev/null | grep $SECOND_IFACE || echo "Interface $SECOND_IFACE no longer visible"

# Step 8: Check Kernel Messages
echo -e "\n=== STEP 8: Check Kernel Messages ==="
echo "Recent kernel messages:"
sudo dmesg | tail -10

# Step 9: Bind to ENA_CUSTOM Driver
echo -e "\n=== STEP 9: Bind to ENA_CUSTOM Driver ==="
echo "Binding $PCI_ADDR to ena_custom driver..."
echo "$PCI_ADDR" | sudo tee /sys/bus/pci/drivers/ena_custom/bind
BIND_RESULT=$?

echo "Bind result: $BIND_RESULT"
sleep 3

echo "Checking if device is bound to ena_custom:"
if [ -d "/sys/bus/pci/drivers/ena_custom/$PCI_ADDR" ]; then
    echo "✓ Device successfully bound to ena_custom driver"
else
    echo "✗ Device not bound to ena_custom driver"
    echo "Checking bind errors:"
    sudo dmesg | tail -5
fi

# Step 10: Check Interface Reappearance
echo -e "\n=== STEP 10: Check Interface Reappearance ==="
echo "Checking if interface reappeared:"
sleep 2
NEW_IFACE=$(ls /sys/class/net/ | grep -E '^(eth|ens)' | grep -v ens5 | head -1)
echo "Interface found: $NEW_IFACE"

if [ -n "$NEW_IFACE" ]; then
    echo "✓ Interface reappeared as: $NEW_IFACE"
    
    # Step 11: Bring Interface Up
    echo -e "\n=== STEP 11: Bring Interface Up ==="
    echo "Bringing up $NEW_IFACE..."
    sudo ip link set $NEW_IFACE up
    if [ $? -eq 0 ]; then
        echo "✓ Interface brought up successfully"
    else
        echo "✗ Failed to bring up interface"
    fi
    
    # Step 12: Final Verification
    echo -e "\n=== STEP 12: Final Verification ==="
    echo "Interface status:"
    ip link show $NEW_IFACE
    
    echo -e "\nDriver information:"
    ethtool -i $NEW_IFACE
    
    echo -e "\nPCI device status:"
    lspci -k | grep -A 2 "$PCI_ADDR"
    
else
    echo "✗ Interface did not reappear"
    echo "Attempting PCI rescan..."
    echo 1 | sudo tee /sys/bus/pci/rescan
    sleep 2
    NEW_IFACE=$(ls /sys/class/net/ | grep -E '^(eth|ens)' | grep -v ens5 | head -1)
    if [ -n "$NEW_IFACE" ]; then
        echo "✓ Interface appeared after rescan: $NEW_IFACE"
    else
        echo "✗ Interface still missing after rescan"
    fi
fi

# Step 13: Final Status Summary
echo -e "\n=== STEP 13: Final Status Summary ==="
echo "All network interfaces:"
ip link show | grep -E '^[0-9]+:'

echo -e "\nAll ENA drivers and their devices:"
lspci -k | grep -A 2 "Ethernet controller"

echo -e "\nLoaded ena modules:"
lsmod | grep ena

echo -e "\nKernel messages (last 15 lines):"
sudo dmesg | tail -15

echo -e "\n=========================================="
echo "ENA Custom Driver Binding - Complete"
echo "=========================================="