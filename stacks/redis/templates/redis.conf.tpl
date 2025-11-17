port 6379
bind 0.0.0.0
protected-mode yes

dir /data
logfile /data/redis-${HOST_PORT}.log
dbfilename dump-${HOST_PORT}.rdb

requirepass ${REDIS_PASSWORD}
masterauth ${REDIS_PASSWORD}

appendonly yes
appendfsync everysec
maxmemory-policy allkeys-lru

# replicaof will be appended dynamically
