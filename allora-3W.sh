#!/bin/bash

# Function to display the styled message
display_message() {
  local msg="by onixia"
  local len=${#msg}
  local border=$(printf "%${len}s" | tr ' ' '-')
  echo -e "\e[1;32m${border}\e[0m"
  echo -e "\e[1;32m$msg\e[0m"
  echo -e "\e[1;32m${border}\e[0m"
}

# Clear the screen and display the message
clear
display_message

# Function for the installation and configuration process
install_and_configure() {
  # Check if re-running after logout
  if [ -f ~/.docker_setup_stage ]; then
    stage=$(cat ~/.docker_setup_stage)
  else
    stage="start"
  fi

  if [ "$stage" == "start" ]; then
    echo -e "\e[1;34m===== Updating System =====\e[0m"
    sudo apt update && sudo apt upgrade -y

    echo -e "\e[1;34m===== Installing Dependencies =====\e[0m"
    sudo apt install -y ca-certificates zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev curl git wget make jq build-essential pkg-config lsb-release libssl-dev libreadline-dev libffi-dev gcc screen unzip lz4 python3 python3-pip

    echo -e "\e[1;34m===== Installing Docker =====\e[0m"
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    docker version

    echo -e "\e[1;34m===== Installing Docker Compose =====\e[0m"
    VER=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
    sudo curl -L "https://github.com/docker/compose/releases/download/$VER/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    docker-compose --version

    echo -e "\e[1;34m===== Setting Docker Permissions =====\e[0m"
    sudo groupadd docker || true
    sudo usermod -aG docker $USER

    echo "docker" > ~/.docker_setup_stage

    echo -e "\e[31mPlease log out and log back in to apply Docker group changes.\e[0m"
    echo -e "\e[31mThen, re-run this script to continue the setup.\e[0m"

    exit 0
  fi

  if [ "$stage" == "docker" ]; then
    echo -e "\e[1;34m===== Installing Go =====\e[0m"
    sudo rm -rf /usr/local/go
    curl -L https://go.dev/dl/go1.22.4.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
    echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile
    echo 'export PATH=$PATH:$(go env GOPATH)/bin' >> $HOME/.bash_profile
    source $HOME/.bash_profile
    go version

    echo -e "\e[1;34m===== Installing Allorad =====\e[0m"
    git clone https://github.com/allora-network/allora-chain.git
    cd allora-chain && make all
    allorad version

    echo -e "\e[1;34m===== Wallet Setup =====\e[0m"
    echo -e "\e[1;33mPlease choose an option:\e[0m"
    echo -e "\e[1;32m1) Create a new wallet\e[0m"
    echo -e "\e[1;32m2) Recover an existing wallet\e[0m"

    while true; do
        read -p "Enter your choice (1 or 2): " wallet_choice
        case $wallet_choice in
            1)
                echo -e "\e[1;36mCreating a new wallet...\e[0m"
                allorad keys add testkey
                break
                ;;
            2)
                echo -e "\e[1;36mRecovering an existing wallet...\e[0m"
                allorad keys add testkey --recover
                break
                ;;
            *)
                echo -e "\e[1;31mInvalid choice. Please enter 1 or 2.\e[0m"
                ;;
        esac
    done

    echo -e "\e[1;32mWallet setup completed successfully!\e[0m"

    echo -e "\e[1;34m===== Installing Workers =====\e[0m"
    cd $HOME && git clone https://github.com/allora-network/basic-coin-prediction-node
    cd basic-coin-prediction-node

    mkdir workers
    mkdir workers/worker-1 workers/worker-2 workers/worker-3 head-data
    sudo chmod -R 777 workers/worker-1 workers/worker-2 workers/worker-3 head-data

    echo -e "\e[1;34m===== Creating Head Keys =====\e[0m"
    sudo docker run -it --entrypoint=bash -v "$PWD/head-data":/data alloranetwork/allora-inference-base:latest -c "mkdir -p /data/keys && (cd /data/keys && allora-keys)"

    echo -e "\e[1;34m===== Creating Worker Keys =====\e[0m"
    for i in {1..3}; do
      sudo docker run -it --entrypoint=bash -v "$PWD/workers/worker-$i":/data alloranetwork/allora-inference-base:latest -c "mkdir -p /data/keys && (cd /data/keys && allora-keys)"
    done

    HEAD_ID=$(cat head-data/keys/identity)
    echo -e "\e[1;33mSave this HEAD_ID: $HEAD_ID\e[0m"

    echo -e "\e[1;34m===== Enter Wallet Seed Phrase =====\e[0m"
    read -p "Enter the WALLET_SEED_PHRASE: " WALLET_SEED_PHRASE

    echo -e "\e[1;34m===== Creating docker-compose.yml =====\e[0m"
    cat > docker-compose.yml <<EOL
version: '3'

services:
  inference:
    container_name: inference
    build:
      context: .
    command: python -u /app/app.py
    ports:
      - "8000:8000"
    networks:
      eth-model-local:
        aliases:
          - inference
        ipv4_address: 172.22.0.4
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/inference/ETH"]
      interval: 10s
      timeout: 10s
      retries: 12
    volumes:
      - ./inference-data:/app/data

  updater:
    container_name: updater
    build: .
    environment:
      - INFERENCE_API_ADDRESS=http://inference:8000
    command: >
      sh -c "
      while true; do
        python -u /app/update_app.py;
        sleep 24h;
      done
      "
    depends_on:
      inference:
        condition: service_healthy
    networks:
      eth-model-local:
        aliases:
          - updater
        ipv4_address: 172.22.0.5

  head:
    container_name: head
    image: alloranetwork/allora-inference-base-head:latest
    environment:
      - HOME=/data
    entrypoint:
      - "/bin/bash"
      - "-c"
      - |
        if [ ! -f /data/keys/priv.bin ]; then
          echo "Generating new private keys..."
          mkdir -p /data/keys
          cd /data/keys
          allora-keys
        fi
        allora-node --role=head --peer-db=/data/peerdb --function-db=/data/function-db  \
          --runtime-path=/app/runtime --runtime-cli=bls-runtime --workspace=/data/workspace \
          --private-key=/data/keys/priv.bin --log-level=debug --port=9010 --rest-api=:6000 \
          --boot-nodes=/dns4/head-0-p2p.v2.testnet.allora.network/tcp/32130/p2p/12D3KooWGKY4z2iNkDMERh5ZD8NBoAX6oWzkDnQboBRGFTpoKNDF
    ports:
      - "6000:6000"
    volumes:
      - ./head-data:/data
    working_dir: /data
    networks:
      eth-model-local:
        aliases:
          - head
        ipv4_address: 172.22.0.100

  worker-1:
    container_name: worker-1
    environment:
      - INFERENCE_API_ADDRESS=http://inference:8000
      - HOME=/data
      - WALLET_SEED_PHRASE=${WALLET_SEED_PHRASE}
      - HEAD_ID=${HEAD_ID}
    build:
      context: .
      dockerfile: Dockerfile_b7s
    entrypoint:
      - "/bin/bash"
      - "-c"
      - |
        if [ ! -f /data/keys/priv.bin ]; then
          echo "Generating new private keys..."
          mkdir -p /data/keys
          cd /data/keys
          allora-keys
        fi
        allora-node --role=worker --peer-db=/data/peerdb --function-db=/data/function-db \
          --runtime-path=/app/runtime --runtime-cli=bls-runtime --workspace=/data/workspace \
          --private-key=/data/keys/priv.bin --log-level=debug --port=9011 \
          --boot-nodes=/ip4/172.22.0.100/tcp/9010/p2p/${HEAD_ID} \
          --topic=allora-topic-1-worker --allora-chain-worker-mode=worker \
          --allora-chain-restore-mnemonic='${WALLET_SEED_PHRASE}' \
          --allora-node-rpc-address=https://allora-rpc.testnet-1.testnet.allora.network/ \
          --allora-chain-key-name=worker-1 \
          --allora-chain-topic-id=1
    volumes:
      - ./workers/worker-1:/data
    working_dir: /data
    depends_on:
      - inference
      - head
    networks:
      eth-model-local:
        aliases:
          - worker1
        ipv4_address: 172.22.0.12

  worker-2:
    container_name: worker-2
    environment:
      - INFERENCE_API_ADDRESS=http://inference:8000
      - HOME=/data
      - WALLET_SEED_PHRASE=${WALLET_SEED_PHRASE}
      - HEAD_ID=${HEAD_ID}
    build:
      context: .
      dockerfile: Dockerfile_b7s
    entrypoint:
      - "/bin/bash"
      - "-c"
      - |
        if [ ! -f /data/keys/priv.bin ]; then
          echo "Generating new private keys..."
          mkdir -p /data/keys
          cd /data/keys
          allora-keys
        fi
        allora-node --role=worker --peer-db=/data/peerdb --function-db=/data/function-db \
          --runtime-path=/app/runtime --runtime-cli=bls-runtime --workspace=/data/workspace \
          --private-key=/data/keys/priv.bin --log-level=debug --port=9013 \
          --boot-nodes=/ip4/172.22.0.100/tcp/9010/p2p/${HEAD_ID} \
          --topic=allora-topic-2-worker --allora-chain-worker-mode=worker \
          --allora-chain-restore-mnemonic='${WALLET_SEED_PHRASE}' \
          --allora-node-rpc-address=https://allora-rpc.testnet-1.testnet.allora.network/ \
          --allora-chain-key-name=worker-2 \
          --allora-chain-topic-id=2
    volumes:
      - ./workers/worker-2:/data
    working_dir: /data
    depends_on:
      - inference
      - head
    networks:
      eth-model-local:
        aliases:
          - worker2
        ipv4_address: 172.22.0.13

  worker-3:
    container_name: worker-3
    environment:
      - INFERENCE_API_ADDRESS=http://inference:8000
      - HOME=/data
      - WALLET_SEED_PHRASE=${WALLET_SEED_PHRASE}
      - HEAD_ID=${HEAD_ID}
    build:
      context: .
      dockerfile: Dockerfile_b7s
    entrypoint:
      - "/bin/bash"
      - "-c"
      - |
        if [ ! -f /data/keys/priv.bin ]; then
          echo "Generating new private keys..."
          mkdir -p /data/keys
          cd /data/keys
          allora-keys
        fi
        allora-node --role=worker --peer-db=/data/peerdb --function-db=/data/function-db \
          --runtime-path=/app/runtime --runtime-cli=bls-runtime --workspace=/data/workspace \
          --private-key=/data/keys/priv.bin --log-level=debug --port=9015 \
          --boot-nodes=/ip4/172.22.0.100/tcp/9010/p2p/${HEAD_ID} \
          --topic=allora-topic-7-worker --allora-chain-worker-mode=worker \
          --allora-chain-restore-mnemonic='${WALLET_SEED_PHRASE}' \
          --allora-node-rpc-address=https://allora-rpc.testnet-1.testnet.allora.network/ \
          --allora-chain-key-name=worker-3 \
          --allora-chain-topic-id=7
    volumes:
      - ./workers/worker-3:/data
    working_dir: /data
    depends_on:
      - inference
      - head
    networks:
      eth-model-local:
        aliases:
          - worker3
        ipv4_address: 172.22.0.14

networks:
  eth-model-local:
    driver: bridge
    ipam:
      config:
        - subnet: 172.22.0.0/24

volumes:
  inference-data:
  workers:
  head-data:
EOL

    echo -e "\e[1;34m===== Running Docker Compose =====\e[0m"
    docker-compose build
    docker-compose up -d

    echo -e "\e[1;32m===== Setup Complete =====\e[0m"
    display_message
    echo "docker" > ~/.docker_setup_stage
  fi
}

# Function to check logs and restart containers if needed
check_logs_and_restart() {
  local containers=("worker-1" "worker-2" "worker-3")
  local retry_count=0
  local max_retries=3
  local error_containers=()
  
  # First pass to check initial status of containers
  for container in "${containers[@]}"; do
    echo -e "\e[1;34mChecking logs for $container...\e[0m"

    # Check logs for errors
    error_count=$(docker logs $container 2>&1 | grep -c "rpc error: code = Unknown desc = rpc error")
    
    if [ "$error_count" -ge "$max_retries" ]; then
      echo -e "\e[1;31mError detected in $container. Marking for restart...\e[0m"
      error_containers+=($container)
    else
      echo -e "\e[1;32m$container is operating normally.\e[0m"
    fi
  done

  # Continue checking and restarting containers until all errors are resolved
  while [ ${#error_containers[@]} -gt 0 ]; do
    for container in "${error_containers[@]}"; do
      echo -e "\e[1;34mChecking logs for $container...\e[0m"

      # Check logs for errors
      error_count=$(docker logs $container 2>&1 | grep -c "rpc error: code = Unknown desc = rpc error")
      
      if [ "$error_count" -ge "$max_retries" ]; then
        echo -e "\e[1;31mError detected in $container. Restarting container...\e[0m"
        docker restart $container
        sleep 60
      else
        echo -e "\e[1;32m$container is operating normally.\e[0m"
        # Remove container from error list if no errors
        error_containers=($(echo "${error_containers[@]}" | tr ' ' '\n' | grep -v "^$container$" | tr '\n' ' '))
      fi
    done
    sleep 60
  done
  
  echo -e "\e[1;32mAll containers are operating normally!\e[0m"
}

# Main script logic
echo -e "\e[1;33mChoose an option:\e[0m"
echo -e "\e[1;32m1) Install and configure\e[0m"
echo -e "\e[1;32m2) Check node status\e[0m"

read -p "Enter your choice (1 or 2): " choice

case $choice in
  1)
    install_and_configure
    ;;
  2)
    check_logs_and_restart
    ;;
  *)
    echo -e "\e[1;31mInvalid choice. Exiting...\e[0m"
    exit 1
    ;;
esac
