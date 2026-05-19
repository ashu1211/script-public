#!/bin/bash

wget $(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep "browser_download_url" | grep "linux-amd64.tar.gz" | cut -d '"' -f 4) -O node_exporter_latest.tar.gz && tar -xvf node_exporter_latest.tar.gz
sudo groupadd -f node_exporter
sudo useradd -g node_exporter --no-create-home --shell /bin/false node_exporter
sudo mkdir /etc/node_exporter
sudo chown node_exporter:node_exporter /etc/node_exporter
mv node_exporter-* node_exporter-files
sudo cp node_exporter-files/node_exporter /usr/bin/
sudo chown node_exporter:node_exporter /usr/bin/node_exporter
rm -rf node_exporter*


sudo su -c "echo '[Unit]
Description=Node Exporter
Documentation=https://prometheus.io/docs/guides/node-exporter/
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
Restart=on-failure
ExecStart=/usr/bin/node_exporter --collector.systemd
  --web.listen-address=:9100

[Install]
WantedBy=multi-user.target' > /usr/lib/systemd/system/node_exporter.service"




sudo chmod 664 /usr/lib/systemd/system/node_exporter.service
sudo systemctl daemon-reload
sudo systemctl start node_exporter

# sudo systemctl status node_exporter


sudo systemctl enable node_exporter.service
