#!/bin/bash

set -e

echo "Creating performance governor script..."
cat <<'EOF' > /usr/local/bin/set_performance_governor.sh
#!/bin/bash
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
  echo performance | sudo tee $cpu > /dev/null
done
EOF

chmod +x /usr/local/bin/set_performance_governor.sh

echo "Creating systemd service for performance governor..."
cat <<EOF > /etc/systemd/system/set-performance-governor.service
[Unit]
Description=Set CPU Governor to Performance

[Service]
Type=oneshot
ExecStart=/usr/local/bin/set_performance_governor.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable set-performance-governor.service
systemctl start set-performance-governor.service

echo "Applying system tuning parameters..."
cat <<EOF > /etc/sysctl.d/21-agave-validator.conf
# Increase UDP buffer sizes
net.core.rmem_default = 134217728
net.core.rmem_max = 134217728
net.core.wmem_default = 134217728
net.core.wmem_max = 134217728

# Increase memory mapped files limit
vm.max_map_count = 1500000

# Increase number of allowed open file descriptors
fs.nr_open = 1000000

# Increase inotify watches and instances
fs.inotify.max_user_instances = 8192
fs.inotify.max_user_watches = 1524288

# System stability and performance tuning
kernel.nmi_watchdog = 0
vm.swappiness = 60
kernel.hung_task_timeout_secs = 600
vm.stat_interval = 10
vm.dirty_ratio = 40
vm.dirty_background_ratio = 10
vm.dirty_expire_centisecs = 36000
vm.dirty_writeback_centisecs = 3000
vm.dirtytime_expire_seconds = 43200
kernel.timer_migration = 0
kernel.pid_max = 65536
net.ipv4.tcp_fastopen = 3
net.core.netdev_max_backlog = 5000
net.ipv4.udp_mem = 12339354 16452473 24678708
vm.nr_hugepages = 2048
EOF

sysctl -p /etc/sysctl.d/21-agave-validator.conf

echo "Setting file descriptor limits..."
cat <<EOF > /etc/security/limits.d/90-solana-nofiles.conf
# Increase process file descriptor count limit
* - nofile 1000000
EOF

echo "System tuning and performance configuration completed."
