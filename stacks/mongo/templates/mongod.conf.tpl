storage:
  dbPath: /data/db

systemLog:
  destination: file
  path: /data/db/mongod-${MONGO_PORT}.log
  logAppend: true

net:
  port: ${MONGO_PORT}
  bindIp: 0.0.0.0

security:
  authorization: enabled
  keyFile: /etc/mongo/keyfile

replication:
  replSetName: ${MONGO_REPLICA_SET}
