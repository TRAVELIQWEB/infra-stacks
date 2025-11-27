version: "3.9"

services:
  wallet-frontend:
    container_name: wallet-frontend-dev
    image: ghcr.io/TRAVELIQWEB/wallet-frontend:dev   # GitHub dev tag
    restart: always
    env_file:
      - ../../secrets/wallet-frontend.env
    ports:
      - "6002:3000"     # HostPort:ContainerPort
    networks:
      - saarthi-net

networks:
  saarthi-net:
    external: true
