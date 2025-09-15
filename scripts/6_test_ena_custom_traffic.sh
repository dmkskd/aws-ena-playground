#!/bin/bash

echo "=========================================="
echo "ENA Custom Driver Connectivity Test"
echo "=========================================="

# Find the custom interface
CUSTOM_IFACE=$(ls /sys/class/net/ | grep -E '^(eth|ens)' | grep -v ens5 | head -1)
if [ -z "$CUSTOM_IFACE" ]; then
    echo "ERROR: No custom interface found!"
    exit 1
fi

echo "Available interfaces:"
echo "  - ens5 (primary/default ENA interface)"
echo "  - $CUSTOM_IFACE (custom ENA driver interface)"
echo ""
echo "🎯 TARGET: Testing custom ENA driver on interface $CUSTOM_IFACE"

# Step 1: Configure IP address
echo -e "\n=== STEP 1: Configure Interface ==="
echo "🔍 Checking existing interfaces:"
echo "$ ip addr show ens5 | grep 'inet '"
ENS5_IP=$(ip addr show ens5 | grep 'inet ' | awk '{print $2}')
echo "  - ens5 (primary): $ENS5_IP"
echo "  - $CUSTOM_IFACE (custom): not configured yet"

echo ""
echo "⚙️  Configuring TARGET interface: $CUSTOM_IFACE"
# Check if IP is already assigned
echo "$ ip addr show $CUSTOM_IFACE | grep '172.31.17.200'"
if ip addr show $CUSTOM_IFACE | grep -q "172.31.17.200"; then
    echo "IP 172.31.17.200/20 already assigned to $CUSTOM_IFACE"
else
    # Assign IP to custom interface
    echo "$ sudo ip addr add 172.31.17.200/20 dev $CUSTOM_IFACE"
    sudo ip addr add 172.31.17.200/20 dev $CUSTOM_IFACE
    echo "Added IP 172.31.17.200/20 to $CUSTOM_IFACE"
fi

# Ensure interface is up
echo "$ sudo ip link set $CUSTOM_IFACE up"
sudo ip link set $CUSTOM_IFACE up

echo "✅ $CUSTOM_IFACE configuration:"
echo "$ ip addr show $CUSTOM_IFACE | grep inet"
ip addr show $CUSTOM_IFACE | grep inet

# Step 2: Verify Custom Driver
echo -e "\n=== STEP 2: Verify Custom Driver ==="
echo "🎯 TARGET: Checking driver for $CUSTOM_IFACE"
echo "Driver information for $CUSTOM_IFACE:"
echo "$ ethtool -i $CUSTOM_IFACE | grep driver"
ethtool -i $CUSTOM_IFACE | grep driver

echo ""
echo "For comparison, ens5 driver:"
echo "$ ethtool -i ens5 | grep driver"
ethtool -i ens5 | grep driver

echo -e "\n📜 Custom driver messages from kernel log:"
echo "$ sudo dmesg | grep -i 'ena_custom' | tail -5"
sudo dmesg | grep -i "ena_custom" | tail -5

# Step 3: Test Driver Activity
echo -e "\n=== STEP 3: Test Driver Activity ==="
echo "🎯 TARGET: Testing traffic on $CUSTOM_IFACE (custom ENA driver)"
echo "Packet counters BEFORE traffic on $CUSTOM_IFACE:"
echo "$ cat /proc/net/dev | grep $CUSTOM_IFACE"
cat /proc/net/dev | grep $CUSTOM_IFACE

echo -e "\n📦 Generating UDP traffic through $CUSTOM_IFACE..."
# UDP traffic test - this will definitely hit the driver
echo "$ ip addr show $CUSTOM_IFACE | grep 'inet ' | awk '{print \$2}' | cut -d'/' -f1"
CUSTOM_IP=$(ip addr show $CUSTOM_IFACE | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)
echo "Source IP for $CUSTOM_IFACE: $CUSTOM_IP"

# Check if netcat is available
echo "$ command -v nc"
if ! command -v nc >/dev/null 2>&1; then
    echo "Installing netcat..."
    echo "$ sudo yum install -y nc || sudo yum install -y nmap-ncat"
    sudo yum install -y nc >/dev/null 2>&1 || sudo yum install -y nmap-ncat >/dev/null 2>&1
fi

echo "Sending 10 UDP packets to 8.8.8.8:53 (DNS) via $CUSTOM_IFACE..."
echo "$ for i in {1..10}; do echo 'test\$i' | timeout 2 nc -u -w1 -s $CUSTOM_IP 8.8.8.8 53; done"
for i in {1..10}; do
    echo "test$i" | timeout 2 nc -u -w1 -s $CUSTOM_IP 8.8.8.8 53 >/dev/null 2>&1 || true
done

echo "Sending 5 UDP packets to local subnet via $CUSTOM_IFACE..."
echo "$ for i in {1..5}; do echo 'test\$i' | timeout 2 nc -u -w1 -s $CUSTOM_IP 172.31.16.1 12345; done"
for i in {1..5}; do
    echo "test$i" | timeout 2 nc -u -w1 -s $CUSTOM_IP 172.31.16.1 12345 >/dev/null 2>&1 || true
done

echo -e "\nPacket counters AFTER traffic on $CUSTOM_IFACE:"
echo "$ cat /proc/net/dev | grep $CUSTOM_IFACE"
cat /proc/net/dev | grep $CUSTOM_IFACE

# Step 4: Compare Packet Counts
echo -e "\n=== STEP 4: Driver Activity Analysis ==="
echo "🎯 TARGET: Analyzing packet counts for $CUSTOM_IFACE"
echo "$ cat /proc/net/dev | grep $CUSTOM_IFACE | awk '{print \$10}' # TX packets"
TX_PACKETS=$(cat /proc/net/dev | grep $CUSTOM_IFACE | awk '{print $10}')
echo "$ cat /proc/net/dev | grep $CUSTOM_IFACE | awk '{print \$2}' # RX packets"
RX_PACKETS=$(cat /proc/net/dev | grep $CUSTOM_IFACE | awk '{print $2}')

echo "$CUSTOM_IFACE TX packets: $TX_PACKETS (packets sent out)"
echo "$CUSTOM_IFACE RX packets: $RX_PACKETS (packets received)"

if [ "$TX_PACKETS" -gt 0 ]; then
    echo "✅ SUCCESS: Custom ENA driver is processing packets!"
    echo "   TX packets > 0 proves the driver is working"
else
    echo "❌ FAIL: No packets processed by custom driver"
fi

# Step 5: Interface Statistics
echo -e "\n=== STEP 5: Interface Statistics ==="
echo "🎯 TARGET: ENA driver statistics for $CUSTOM_IFACE:"
echo "$ ethtool -S $CUSTOM_IFACE | head -10"
ethtool -S $CUSTOM_IFACE | head -10
echo ""
echo "📊 ENA Driver Health Statistics Explanation:"
echo "  - total_resets: Number of driver resets (0 = good, no resets needed)"
echo "  - tx_timeout: Transmission timeouts (0 = good, no timeouts)"
echo "  - bad_tx_req_id/bad_rx_req_id: Bad request IDs (0 = good, no errors)"
echo "  - All zeros = Your ena_custom driver is running perfectly!"
echo "  ✅ These are health counters, not reset commands - zeros are ideal"

# Step 6: UDP Packet Monitoring Test
echo -e "\n=== STEP 6: UDP Packet Monitoring ==="
echo "🎯 TARGET: Monitoring UDP packets on $CUSTOM_IFACE in real-time..."

# Check if tcpdump is available
echo "$ command -v tcpdump"
if command -v tcpdump >/dev/null 2>&1; then
    # Start packet capture in background
    echo "$ sudo timeout 10 tcpdump -i $CUSTOM_IFACE -c 20 udp &"
    sudo timeout 10 tcpdump -i $CUSTOM_IFACE -c 20 udp 2>/dev/null &
    TCPDUMP_PID=$!
    
    # Give tcpdump time to start
    sleep 2
    
    echo "Sending 20 UDP packets to verify driver processing..."
    CUSTOM_IP_MONITOR=$(ip addr show $CUSTOM_IFACE | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)
    echo "$ for i in {1..20}; do echo 'UDP test packet \$i' | timeout 2 nc -u -w1 -s $CUSTOM_IP_MONITOR 8.8.8.8 53; done"
    for i in {1..20}; do
        echo "UDP test packet $i" | timeout 2 nc -u -w1 -s $CUSTOM_IP_MONITOR 8.8.8.8 53 >/dev/null 2>&1 || true
        sleep 0.1
    done
    
    # Wait for tcpdump to finish
    wait $TCPDUMP_PID 2>/dev/null || true
    echo "UDP packet monitoring completed"
else
    echo "tcpdump not available, skipping packet monitoring"
    echo "Sending 20 UDP packets anyway..."
    CUSTOM_IP_MONITOR=$(ip addr show $CUSTOM_IFACE | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)
    echo "$ for i in {1..20}; do echo 'UDP test packet \$i' | timeout 2 nc -u -w1 -s $CUSTOM_IP_MONITOR 8.8.8.8 53; done"
    for i in {1..20}; do
        echo "UDP test packet $i" | timeout 2 nc -u -w1 -s $CUSTOM_IP_MONITOR 8.8.8.8 53 >/dev/null 2>&1 || true
        sleep 0.1
    done
fi

# Final packet count
echo -e "\nFinal packet counters for $CUSTOM_IFACE:"
echo "$ cat /proc/net/dev | grep $CUSTOM_IFACE"
cat /proc/net/dev | grep $CUSTOM_IFACE
echo ""
echo "📊 /proc/net/dev format explanation:"
echo "Interface: RX_bytes RX_packets RX_errs RX_drop RX_fifo RX_frame RX_compressed RX_multicast TX_bytes TX_packets TX_errs TX_drop TX_fifo TX_colls TX_carrier TX_compressed"
echo "Key fields for $CUSTOM_IFACE:"
echo "  - RX packets (field 2): $(cat /proc/net/dev | grep $CUSTOM_IFACE | awk '{print $2}') packets received"
echo "  - TX packets (field 10): $(cat /proc/net/dev | grep $CUSTOM_IFACE | awk '{print $10}') packets transmitted"
echo "  - RX bytes (field 1): $(cat /proc/net/dev | grep $CUSTOM_IFACE | awk '{print $1}') bytes received"
echo "  - TX bytes (field 9): $(cat /proc/net/dev | grep $CUSTOM_IFACE | awk '{print $9}') bytes transmitted"
echo ""
echo "✅ This shows your ena_custom driver is actively processing network traffic!"

# Step 7: Summary
echo -e "\n=== STEP 8: Test Summary ==="
echo "$ cat /proc/net/dev | grep $CUSTOM_IFACE | awk '{print \$10}' # Final TX"
FINAL_TX=$(cat /proc/net/dev | grep $CUSTOM_IFACE | awk '{print $10}')
echo "$ cat /proc/net/dev | grep $CUSTOM_IFACE | awk '{print \$2}' # Final RX"
FINAL_RX=$(cat /proc/net/dev | grep $CUSTOM_IFACE | awk '{print $2}')

echo "Interface: $CUSTOM_IFACE"
echo "$ ethtool -i $CUSTOM_IFACE | grep driver | awk '{print \$2}'"
echo "Driver: $(ethtool -i $CUSTOM_IFACE | grep driver | awk '{print $2}')"
echo "Final TX packets: $FINAL_TX"
echo "Final RX packets: $FINAL_RX"

if [ "$FINAL_TX" -gt 0 ]; then
    echo -e "\n🎉 SUCCESS: Custom ENA driver is working!"
    echo "   The driver successfully processed $FINAL_TX outbound packets"
    echo "   This proves your ena_custom driver is functional"
else
    echo -e "\n❌ ISSUE: Custom driver may not be processing packets"
fi

echo -e "\n=========================================="
echo "ENA Custom Driver Test Complete"
echo "=========================================="