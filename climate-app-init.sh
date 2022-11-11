#RASPBERRY PI ZERO 2 W SETUP

#VARIABLES

ROOT_FOLDER_NAME='/var/www'
PROJECT_FOLDER_NAME='tempSensorAPI'
PROJECT_NAME='tempSensorAPI'
PROMETHEUS_INSTALLER_ZIP='prometheus-2.36.0.linux-armv5.tar.gz'
PROMETHEUS_INSTALLER='prometheus-2.36.0.linux-armv5'
PROJECT_PORT='5001'
SCRAPE_INTERVAL='15s'
EVALUATION_INTERVAL='15s'

# #SCRIPT

apt update
apt install python3-pip
pip install virtualenv

# mkdir $ROOT_FOLDER_NAME

cp $PROJECT_FOLDER_NAME /var/www/  

chown -R $USER:www-data $ROOT_FOLDER_NAME'/'"$PROJECT_NAME"
chmod -R 777 /var/www
chmod a+rwx /var/www/"$PROJECT_NAME"
ufw allow 5001

apt install nginx
systemctl enable nginx
systemctl start nginx

cd /etc/systemd/system/

echo '[Unit]' > "$PROJECT_NAME".service
echo 'After=network.target' >> "$PROJECT_NAME".service
echo '' >> "$PROJECT_NAME".service
echo '[Service]' >> "$PROJECT_NAME".service
echo 'User=ubuntu' >> "$PROJECT_NAME".service
echo 'Group=www-data' >> "$PROJECT_NAME".service
echo 'Environment="PATH=/var/www/'${PROJECT_NAME}'/env/bin"' >> "$PROJECT_NAME".service
echo 'WorkingDirectory=/var/www/'${PROJECT_NAME}'/' >> "$PROJECT_NAME".service
echo 'ExecStart=/var/www/'${PROJECT_NAME}'/env/bin/gunicorn --workers 1 \' >> "$PROJECT_NAME".service
echo '--bind unix:/var/www/'${PROJECT_NAME}'/'${PROJECT_NAME}'.sock wsgi:app' >> "$PROJECT_NAME".service
echo '' >> "$PROJECT_NAME".service
echo '[Install]' >> "$PROJECT_NAME".service
echo 'WantedBy=multi-user.target' >> "$PROJECT_NAME".service

systemctl enable "$PROJECT_NAME".service
systemctl start "$PROJECT_NAME".service

cd /etc/nginx/sites-available/

echo 'server {' > "$PROJECT_NAME".conf
echo '        listen 80;' >> "$PROJECT_NAME".conf
echo '        server_name '${PROJECT_NAME} 'www.'${PROJECT_NAME}';' >> "$PROJECT_NAME".conf
echo '' >> "$PROJECT_NAME".conf
echo '        access_log /var/log/nginx/'${PROJECT_NAME}'.access.log;' >> "$PROJECT_NAME".conf
echo '        error_log /var/log/nginx/'${PROJECT_NAME}'.error.log;' >> "$PROJECT_NAME".conf
echo '' >> "$PROJECT_NAME".conf
echo '        location / {' >> "$PROJECT_NAME".conf
echo '                include proxy_params;' >> "$PROJECT_NAME".conf
echo '                proxy_pass http://unix:/var/www/'${PROJECT_NAME}'/'${PROJECT_NAME}.sock';' >> "$PROJECT_NAME".conf
echo '        }' >> "$PROJECT_NAME".conf
echo '}' >> "$PROJECT_NAME".conf

ln -s /etc/nginx/sites-available/"$PROJECT_NAME".conf /etc/nginx/sites-enabled/
nginx -t
systemctl restart nginx

#PROMETHEUS

groupadd --system prometheus

useradd -s /sbin/nologin --system -g prometheus prometheus

mkdir /var/lib/prometheus

for i in rules rules.d files_sd; do mkdir -p /etc/prometheus/${i}; done

cd $ROOT_FOLDER_NAME

tar xvf $PROMETHEUS_INSTALLER_ZIP

cd $PROMETHEUS_INSTALLER

mv prometheus promtool /usr/local/bin/

mv prometheus.yml /etc/prometheus/prometheus.yml

mv consoles/ console_libraries/ /etc/prometheus/

cd /etc/prometheus/

: > prometheus.yml

echo 'global:' >> prometheus.yml
echo '  scrape_interval:     '${SCRAPE_INTERVAL} >> prometheus.yml
echo '  evaluation_interval: '${EVALUATION_INTERVAL} >> prometheus.yml
echo '' >> prometheus.yml
echo 'alerting:' >> prometheus.yml
echo '  alertmanagers:' >> prometheus.yml
echo '  - static_configs:' >> prometheus.yml
echo '    - targets:' >> prometheus.yml
echo '          # - alertmanager:9093' >> prometheus.yml
echo '' >> prometheus.yml
echo 'rule_files:' >> prometheus.yml
echo '  # - "first_rules.yml"' >> prometheus.yml
echo '  # - "second_rules.yml"' >> prometheus.yml
echo '' >> prometheus.yml
echo 'scrape_configs:' >> prometheus.yml
echo "  - job_name: 'prometheus'" >> prometheus.yml
echo '    static_configs:' >> prometheus.yml
echo "    - targets: ['localhost:"${PROJECT_PORT}"']" >> prometheus.yml

cd /etc/systemd/system/

echo '[Unit]' > prometheus.service
echo 'Description=Prometheus' >> prometheus.service
echo 'Documentation=https://prometheus.io/docs/introduction/overview/' >> prometheus.service
echo 'Wants=network-online.target' >> prometheus.service
echo 'After=network-online.target' >> prometheus.service
echo '' >> prometheus.service
echo '[Service]' >> prometheus.service
echo 'Type=simple' >> prometheus.service
echo 'User=prometheus' >> prometheus.service
echo 'Group=prometheus' >> prometheus.service
echo 'ExecReload=/bin/kill -HUP \$MAINPID' >> prometheus.service
echo 'ExecStart=/usr/local/bin/prometheus \' >> prometheus.service
echo '  --config.file=/etc/prometheus/prometheus.yml \' >> prometheus.service
echo '  --storage.tsdb.path=/var/lib/prometheus \' >> prometheus.service
echo '  --storage.tsdb.retention.time=30d \' >> prometheus.service
echo '  --storage.tsdb.retention.size=0 \' >> prometheus.service
echo '  --web.console.templates=/etc/prometheus/consoles \' >> prometheus.service
echo '  --web.console.libraries=/etc/prometheus/console_libraries \' >> prometheus.service
echo '  --web.listen-address=0.0.0.0:9090 \' >> prometheus.service
echo '  --web.enable-admin-api \' >> prometheus.service
echo '  --web.external-url=' >> prometheus.service
echo '' >> prometheus.service
echo 'SyslogIdentifier=prometheus' >> prometheus.service
echo 'Restart=always' >> prometheus.service
echo '' >> prometheus.service
echo '[Install]' >> prometheus.service
echo 'WantedBy=multi-user.target' >> prometheus.service
echo 'EOF' >> prometheus.service

for i in rules rules.d files_sd; do chown -R prometheus:prometheus /etc/prometheus/${i}; done
for i in rules rules.d files_sd; do chmod -R 775 /etc/prometheus/${i}; done
chown -R prometheus:prometheus /var/lib/prometheus/

systemctl daemon-reload
systemctl start prometheus
systemctl enable prometheus

ufw allow 9090/tcp
