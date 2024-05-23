#!/bin/bash

# Solicitação de dados ao usuário
echo -e "\e[32m==============================================================================\e[0m"
echo -e "\e[32m=                                                                            =\e[0m"
echo -e "\e[32m=                 \e[33mPreencha as informações solicitadas abaixo\e[32m                 =\e[0m"
echo -e "\e[32m=                                                                            =\e[0m"
echo -e "\e[32m==============================================================================\e[0m"

echo ""
read -p "Endereço de e-mail: " email
read -p "Dominio do Traefik (ex: traefik.seudominio.com): " traefik
read -p "Senha do Traefik: " senha
read -p "Dominio do Portainer (ex: portainer.seudominio.com): " portainer
read -p "Dominio do MinIO (ex: minio.seudominio.com): " minio
read -p "Dominio do n8n (ex: n8n.seudominio.com): " n8n
read -p "Dominio do Edge (ex: edge.seudominio.com): " edge

# Verificação dos dados
clear
echo ""
echo "Seu E-mail: $email"
echo "Dominio do Traefik: $traefik"
echo "Senha do Traefik: $senha"
echo "Dominio do Portainer: $portainer"
echo "Dominio do MinIO: $minio"
echo "Dominio do n8n: $n8n"
echo "Dominio do Edge: $edge"
echo ""
read -p "As informações estão corretas? (y/n): " confirma1

if [ "$confirma1" != "y" ]; then
    echo "Encerrando a instalação. Por favor, inicie a instalação novamente."
    exit 0
fi

clear

# Início da instalação automática
echo -e "\e[32mIniciando a instalação automática...\e[0m"

# Atualização e instalação de dependências
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y curl

# Instalação do Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Criação do diretório e navegação
mkdir -p ~/Portainer
cd ~/Portainer

# Criação do arquivo docker-compose.yml
cat > docker-compose.yml <<EOL
version: "3.3"
services:
  traefik:
    container_name: traefik
    image: "traefik:latest"
    restart: always
    command:
      - --entrypoints.web.address=:80
      - --entrypoints.websecure.address=:443
      - --api.insecure=true
      - --api.dashboard=true
      - --providers.docker
      - --log.level=ERROR
      - --certificatesresolvers.leresolver.acme.httpchallenge=true
      - --certificatesresolvers.leresolver.acme.email=$email
      - --certificatesresolvers.leresolver.acme.storage=./acme.json
      - --certificatesresolvers.leresolver.acme.httpchallenge.entrypoint=web
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "./acme.json:/acme.json"
    labels:
      - "traefik.http.routers.http-catchall.rule=hostregexp(\`{host:.+}\`)"
      - "traefik.http.routers.http-catchall.entrypoints=web"
      - "traefik.http.routers.http-catchall.middlewares=redirect-to-https"
      - "traefik.http.middlewares.redirect-to-https.redirectscheme.scheme=https"
      - "traefik.http.routers.traefik-dashboard.rule=Host(\`$traefik\`)"
      - "traefik.http.routers.traefik-dashboard.entrypoints=websecure"
      - "traefik.http.routers.traefik-dashboard.service=api@internal"
      - "traefik.http.routers.traefik-dashboard.tls.certresolver=leresolver"
      - "traefik.http.middlewares.traefik-auth.basicauth.users=admin:$senha"

  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: always
    command: -H unix:///var/run/docker.sock
    ports:
      - "9000:9000"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock"
      - "portainer_data:/data"
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.portainer.rule=Host(\`$portainer\`)"
      - "traefik.http.routers.portainer.entrypoints=websecure"
      - "traefik.http.routers.portainer.tls.certresolver=leresolver"

  minio:
    image: minio/minio:latest
    container_name: minio
    restart: always
    ports:
      - "9001:9001"
    environment:
      - MINIO_ROOT_USER=minioadmin
      - MINIO_ROOT_PASSWORD=minioadminpassword
    command: server /data --console-address ":9001"
    volumes:
      - "minio_data:/data"
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.minio.rule=Host(\`$minio\`)"
      - "traefik.http.routers.minio.entrypoints=websecure"
      - "traefik.http.routers.minio.tls.certresolver=leresolver"

  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: always
    ports:
      - "5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=n8nuser
      - N8N_BASIC_AUTH_PASSWORD=n8npassword
    volumes:
      - "n8n_data:/home/node/.n8n"
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.n8n.rule=Host(\`$n8n\`)"
      - "traefik.http.routers.n8n.entrypoints=websecure"
      - "traefik.http.routers.n8n.tls.certresolver=leresolver"

volumes:
  portainer_data:
  minio_data:
  n8n_data:
EOL

# Configuração de permissões e criação de arquivos necessários
touch acme.json
sudo chmod 600 acme.json

# Iniciando os serviços com Docker Compose
sudo docker-compose up -d

# Mensagem de conclusão
echo -e "\e[32m==============================================================================\e[0m"
echo -e "\e[32m=                                                                            =\e[0m"
echo -e "\e[32m=                  \e[33mTodos os serviços foram configurados\e[32m                 =\e[0m"
echo -e "\e[32m=                                                                            =\e[0m"
echo -e "\e[32m==============================================================================\e[0m"
echo ""
echo -e "\e[32mAcesse os seguintes serviços nos domínios configurados:\e[0m"
echo -e "\e[32mTraefik Dashboard: \e[33m$traefik\e[0m"
echo -e "\e[32mPortainer: \e[33m$portainer\e[0m"
echo -e "\e[32mMinIO: \e[33m$minio\e[0m"
echo -e "\e[32mn8n: \e[33m$n8n\e[0m"
echo -e "\e[32mEdge: \e[33m$edge\e[0m"
echo ""
echo -e "\e[32mCredenciais padrão:\e[0m"
echo -e "\e[32mMinIO:\e[0m"
echo -e "\e[32mUsuário: minioadmin\e[0m"
echo -e "\e[32mSenha: minioadminpassword\e[0m"
echo -e "\e[32mn8n:\e[0m"
echo -e "\e[32mUsuário: n8nuser\e[0m"
echo -e "\e[32mSenha: n8npassword\e[0m"
