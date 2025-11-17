
port 6379
bind 0.0.0.0
protected-mode yes

dir /data
logfile /data/redis-${HOST_PORT}.log
dbfilename dump-${HOST_PORT}.rdb

requirepass ${REDIS_PASSWORD}
masterauth ${REDIS_PASSWORD}

# 🔥 AOF – strongest persistence
appendonly yes
appendfsync everysec

# 🔥 RDB – periodic full snapshots
save 900 1
save 300 100
save 60 10000

maxmemory-policy allkeys-lru
