#!/bin/bash
set -e
exec > /var/log/user-data.log 2>&1

apt-get update -y
apt-get install -y gnupg curl awscli

# Install MongoDB 4.4
curl -fsSL https://www.mongodb.org/static/pgp/server-4.4.asc | apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" \
  | tee /etc/apt/sources.list.d/mongodb-org-4.4.list

apt-get update -y
apt-get install -y \
  mongodb-org=4.4.29 \
  mongodb-org-server=4.4.29 \
  mongodb-org-shell=4.4.29 \
  mongodb-org-mongos=4.4.29 \
  mongodb-org-tools=4.4.29

echo "mongodb-org hold"        | dpkg --set-selections
echo "mongodb-org-server hold" | dpkg --set-selections
echo "mongodb-org-shell hold"  | dpkg --set-selections
echo "mongodb-org-mongos hold" | dpkg --set-selections
echo "mongodb-org-tools hold"  | dpkg --set-selections

systemctl enable mongod
systemctl start mongod
sleep 15

# Create admin and app users
mongo admin --eval "
  db.createUser({
    user: 'admin',
    pwd:  '${mongo_admin_password}',
    roles: [
      { role: 'userAdminAnyDatabase', db: 'admin' },
      { role: 'readWriteAnyDatabase', db: 'admin' }
    ]
  })
"

mongo tasky -u admin -p '${mongo_admin_password}' --authenticationDatabase admin --eval "
  db.createUser({
    user: 'taskyuser',
    pwd:  '${mongo_app_password}',
    roles: [{ role: 'readWrite', db: 'tasky' }]
  })
"

# Configure MongoDB: enable auth
cat > /etc/mongod.conf <<'MONGOCONF'
storage:
  dbPath: /var/lib/mongodb
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log
net:
  port: 27017
  bindIp: 0.0.0.0
processManagement:
  timeZoneInfo: /usr/share/zoneinfo
security:
  authorization: enabled
MONGOCONF

systemctl restart mongod
sleep 5

# Daily automated backup to S3
cat > /usr/local/bin/mongo-backup.sh <<'BACKUPEOF'
#!/bin/bash
set -e
DATE=$(date +%Y_%m_%d__%H_%M_%S)
BACKUP_DIR="/tmp/mongobackup_$${DATE}"
mkdir -p "$${BACKUP_DIR}"

echo "Starting MongoDB backup..."

mongodump \
  --uri "mongodb://admin:${mongo_admin_password}@127.0.0.1:27017/admin?authSource=admin" \
  --out "$${BACKUP_DIR}"

tar -czf "/tmp/mongobackup_$${DATE}.tar.gz" -C /tmp "mongobackup_$${DATE}"

aws s3 cp "/tmp/mongobackup_$${DATE}.tar.gz" \
  "s3://${backup_bucket}/backups/mongobackup_$${DATE}.tar.gz" \
  --region ${aws_region}

rm -rf "$${BACKUP_DIR}" "/tmp/mongobackup_$${DATE}.tar.gz"
echo "Backup complete: mongobackup_$${DATE}.tar.gz"
BACKUPEOF

chmod +x /usr/local/bin/mongo-backup.sh

# Schedule daily
echo "0 0 * * * root /usr/local/bin/mongo-backup.sh >> /var/log/mongo-backup.log 2>&1" >> /etc/crontab

# Initial backup
/usr/local/bin/mongo-backup.sh || true

echo "Bootstrap complete."
