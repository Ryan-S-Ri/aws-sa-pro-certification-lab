#!/bin/bash

# Raspberry Pi System Monitor for AWS Lab Management

echo "🥧 Raspberry Pi System Status"
echo "============================"

# System temperature
if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
    TEMP=$(cat /sys/class/thermal/thermal_zone0/temp)
    TEMP_C=$((TEMP/1000))
    echo "🌡️  CPU Temperature: ${TEMP_C}°C"
    
    if [ $TEMP_C -gt 70 ]; then
        echo "⚠️  High temperature detected!"
    fi
fi

# Memory usage
echo "💾 Memory Usage:"
free -h | head -2

# Disk usage
echo "💿 Disk Usage:"
df -h / | tail -1

# CPU load
echo "⚙️  CPU Load:"
uptime

# Terraform processes
echo "🏗️  Terraform Processes:"
pgrep -f terraform | wc -l | xargs echo "Active processes:"

# AWS CLI rate limiting status
echo "☁️  AWS Status:"
if command -v aws &> /dev/null; then
    echo "AWS CLI: $(aws --version 2>&1 | cut -d/ -f2 | cut -d' ' -f1)"
else
    echo "AWS CLI: Not installed"
fi

# Network connectivity
echo "🌐 Network:"
if ping -c 1 8.8.8.8 &> /dev/null; then
    echo "Internet: Connected"
else
    echo "Internet: Disconnected"
fi

# Power supply status
if [ -f /sys/class/power_supply/rpi-poe/online ]; then
    POE_STATUS=$(cat /sys/class/power_supply/rpi-poe/online)
    echo "🔌 PoE: $([[ $POE_STATUS == "1" ]] && echo "Active" || echo "Inactive")"
fi
