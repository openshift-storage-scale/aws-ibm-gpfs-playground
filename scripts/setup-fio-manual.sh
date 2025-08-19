#!/bin/bash

# Manual FIO Setup Script
# Run this script after connecting to the VM via: virtctl ssh --namespace virt-test -t="-o StrictHostKeyChecking=no" -t="-o UserKnownHostsFile=/dev/null" fedora@fio-test

set -e

echo "🔧 Setting up FIO as systemd service..."

# Check if FIO is available
if ! command -v fio &> /dev/null; then
    echo "❌ FIO not found. Installing..."
    sudo dnf install -y fio
fi

# Create systemd service file
sudo tee /etc/systemd/system/fio-test.service > /dev/null << 'EOF'
[Unit]
Description=FIO Test Service for VM Migration Testing
After=network.target

[Service]
Type=simple
User=fedora
WorkingDirectory=/home/fedora
ExecStart=/usr/bin/fio --name=randrw --ioengine=libaio --direct=1 --rw=randrw --bs=4k --size=1G --numjobs=2 --iodepth=8 --time_based --runtime=31536000 --verify=crc32c --verify_fatal=1 --group_reporting --directory=/home/fedora --log_avg_msec=1000 --write_bw_log=/home/fedora/fio --write_lat_log=/home/fedora/fio --write_iops_log=/home/fedora/fio
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Create golden checksum files for integrity testing
echo "📝 Creating golden checksum files..."
cd /home/fedora
dd if=/dev/urandom of=gold-1.bin bs=1M count=16 status=none
dd if=/dev/urandom of=gold-2.bin bs=1M count=16 status=none
dd if=/dev/urandom of=gold-3.bin bs=1M count=16 status=none
dd if=/dev/urandom of=gold-4.bin bs=1M count=16 status=none
sha256sum gold-*.bin > gold.sha256

# Reload systemd and enable/start the service
echo "🚀 Starting FIO service..."
sudo systemctl daemon-reload
sudo systemctl enable fio-test.service
sudo systemctl start fio-test.service

# Verify the service is running
echo "✅ Verifying FIO service status..."
sudo systemctl status fio-test.service --no-pager -l

echo ""
echo "🎯 FIO Setup Complete!"
echo "Service: fio-test.service"
echo "Logs: sudo journalctl -u fio-test.service -f"
echo "Status: sudo systemctl status fio-test.service"
echo "Golden checksums: /home/fedora/gold.sha256"
echo ""
echo "To check for data corruption after migrations, run:"
echo "  sha256sum -c /home/fedora/gold.sha256"
echo "  sudo journalctl -u fio-test.service --since '1 hour ago' | grep -i error"
