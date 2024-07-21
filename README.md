# Allora 3 Workers Setup Guide

## Preparation

Before running the new setup script, ensure you clean up any existing Docker containers and directories:

1. **Navigate to the right directory**:
    ```bash
    cd $HOME && cd basic-coin-prediction-node
    ```
    # or 
    ```bash
    cd $HOME && cd allora-chain/basic-coin-prediction-node
    ```

2. **Remove existing worker containers**:
    ```bash
    docker container stop worker-1
    docker container rm worker-1

    docker container stop worker-2
    docker container rm worker-2
    ```

3. **Remove old project directories**:
    ```bash
    cd $HOME
    rm -rf allora-chain
    rm -rf basic-coin-prediction-node
    ```

## Setup New Script

1. **Download and run the setup script**:
    ```bash
    wget https://raw.githubusercontent.com/Onixs50/allora-3-workers/main/allora.sh
    chmod +x allora.sh
    ./allora.sh
    ```

2. **Log out and log back in** to apply Docker group changes (if you have recently updated Docker permissions).

3. **Re-run the setup script** after logging back in:
    ```bash
    ./allora.sh
    ```

## Check Node Status

After running the setup script, you can monitor the status of your workers with the following commands:

- **Check logs for worker-1**:
    ```bash
    docker compose logs -f worker-1
    ```

- **Check logs for worker-2**:
    ```bash
    docker compose logs -f worker-2
    ```

- **Check logs for worker-3**:
    ```bash
    docker compose logs -f worker-3
    ```
## Verify Worker 

After running the setup script and re-running it after logging back in, you should check if each worker node is functioning correctly.

### Check Worker-1 

Run the following command to check if your worker-1 node is working well:

```bash
network_height=$(curl -s -X 'GET' 'https://allora-rpc.testnet-1.testnet.allora.network/abci_info?' -H 'accept: application/json' | jq -r .result.response.last_block_height) && \
curl --location 'http://localhost:6000/api/v1/functions/execute' --header 'Content-Type: application/json' --data '{
    "function_id": "bafybeigpiwl3o73zvvl6dxdqu7zqcub5mhg65jiky2xqb4rdhfmikswzqm",
    "method": "allora-inference-function.wasm",
    "parameters": null,
    "topic": "1",
    "config": {
        "env_vars": [
            {
                "name": "BLS_REQUEST_PATH",
                "value": "/api"
            },
            {
                "name": "ALLORA_ARG_PARAMS",
                "value": "ETH"
            },
            {
                "name": "ALLORA_BLOCK_HEIGHT_CURRENT",
                "value": "'"${network_height}"'"
            }
        ],
        "number_of_nodes": -1,
        "timeout": 10
    }
}' | jq
```
### Check Worker-2
```bash
network_height=$(curl -s -X 'GET' 'https://allora-rpc.testnet-1.testnet.allora.network/abci_info?' -H 'accept: application/json' | jq -r .result.response.last_block_height) && \
curl --location 'http://localhost:6000/api/v1/functions/execute' --header 'Content-Type: application/json' --data '{
    "function_id": "bafybeigpiwl3o73zvvl6dxdqu7zqcub5mhg65jiky2xqb4rdhfmikswzqm",
    "method": "allora-inference-function.wasm",
    "parameters": null,
    "topic": "2",
    "config": {
        "env_vars": [
            {
                "name": "BLS_REQUEST_PATH",
                "value": "/api"
            },
            {
                "name": "ALLORA_ARG_PARAMS",
                "value": "ETH"
            },
            {
                "name": "ALLORA_BLOCK_HEIGHT_CURRENT",
                "value": "'"${network_height}"'"
            }
        ],
        "number_of_nodes": -1,
        "timeout": 10
    }
}' | jq
```
### Check Worker-3
```bash
network_height=$(curl -s -X 'GET' 'https://allora-rpc.testnet-1.testnet.allora.network/abci_info?' -H 'accept: application/json' | jq -r .result.response.last_block_height) && \
curl --location 'http://localhost:6000/api/v1/functions/execute' --header 'Content-Type: application/json' --data '{
    "function_id": "bafybeigpiwl3o73zvvl6dxdqu7zqcub5mhg65jiky2xqb4rdhfmikswzqm",
    "method": "allora-inference-function.wasm",
    "parameters": null,
    "topic": "7",
    "config": {
        "env_vars": [
            {
                "name": "BLS_REQUEST_PATH",
                "value": "/api"
            },
            {
                "name": "ALLORA_ARG_PARAMS",
                "value": "ETH"
            },
            {
                "name": "ALLORA_BLOCK_HEIGHT_CURRENT",
                "value": "'"${network_height}"'"
            }
        ],
        "number_of_nodes": -1,
        "timeout": 10
    }
}' | jq
```
## Wallet Setup

When you run the setup script, you will be prompted to create a new wallet or recover an existing one. Follow these instructions:

1. **Create a New Wallet:**
   - When you see the prompt `Do you want to create a new wallet or recover an existing one? (create/recover)`, type `create`.
   - Follow the on-screen instructions to generate a new wallet.
   - Make sure to securely save the 12 or 24-word seed phrase provided.

2. **Recover an Existing Wallet:**
   - When you see the prompt `Do you want to create a new wallet or recover an existing one? (create/recover)`, type `recover`.
   - Enter your 12 or 24-word seed phrase when prompted to restore your wallet.

**Note:** Ensure you store your seed phrase securely. This phrase is crucial for recovering your wallet in case of loss.

For any issues or further assistance, feel free to open an issue in the [GitHub repository](https://github.com/Onixs50/allora-3-workers).

