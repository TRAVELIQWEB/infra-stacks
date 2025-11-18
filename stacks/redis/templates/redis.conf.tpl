port 6379
bind 127.0.0.1 10.50.0.0/24 122.160.75.47 223.239.129.116 103.99.37.218
protected-mode yes

dir /data
logfile /data/redis-${HOST_PORT}.log
dbfilename dump-${HOST_PORT}.rdb

requirepass ${REDIS_PASSWORD}
masterauth ${REDIS_PASSWORD}

appendonly yes
appendfsync everysec

save 900 1
save 300 100
save 60 10000

maxmemory-policy allkeys-lru

###############################################
# Replica announce fix (NO CONDITION HERE)
###############################################
#slave-announce-ip ${PUBLIC_IP}
#slave-announce-port ${HOST_PORT}

# NOTE:
# Replica settings (replicaof <ip> <port>) are added automatically
# by setup-instance.sh when role=replica.