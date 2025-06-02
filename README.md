# vLLM Server Launcher

This script is designed to launch a vLLM server with configurations loaded from a YAML file, while allowing command-line arguments to override configuration values dynamically. It also supports setting CUDA devices for GPU utilization.

## Features

- Loads configuration from a YAML file.
- Allows command-line arguments to override YAML config values.
- Supports setting `CUDA_VISIBLE_DEVICES` via CLI or config file.
- Extracts valid vLLM arguments dynamically from `vllm serve --help`.
- Logs configuration details for debugging.

## Installation

Ensure you have Python installed along with the necessary dependencies listed in the `requirements.txt` file:

```bash
# Load appropriate modules and activate virtualenv
module purge && module load mkl intel python/3.12
# Important to avoid the virtual env using global packages
unset PYTHONPATH
python -m venv venv_mn5
source venv_mn5/bin/activate
pip install -r requirements.txt
```

### Downloading Models from Hugging Face

Use the provided Bash script to download models from Hugging Face. By default, models will be saved to `/gpfs/project/bsc02/sla/llm_models/huggingface_models`.

#### Download Script

To download a model, run the script with the model URL obtained on HuggingFace:
```bash
bash ./scripts/hf_dl.sh <model_name>
```
For example:
```bash
bash ./scripts/hf_dl.sh meta-llama/Llama-2-7b-hf
```

This will download the model to `/gpfs/project/bsc02/sla/llm_models/huggingface_models/Llama-2-7b-hf`.
It is better to keep that folder common to all project to avoid downloading same models twice as they are very large.

#### Hugging Face Authentication

Some models require authentication via a Hugging Face token. You can generate a token from your [Hugging Face account settings](https://huggingface.co/settings/tokens). Once generated, set the token in your environment:
```bash
export HUGGINGFACE_HUB_TOKEN=your_token_here
```
Alternatively, you can log in using the CLI:

```bash
huggingface-cli login
```

## Usage

### Running a node
This is being tested with interactive session on the ACC-4. It should work on bsc_life queue too. 
Example using 1hour node with 4 GPUs:

```bash
salloc -A bsc02 -t 01:00:00 -q acc_interactive -n 1 -c 80 --gres=gpu:4
```

### Running the Script

Basic usage with a configuration file:

```bash
# Load appropriate modules and activate virtualenv
module purge && module load mkl intel python/3.12
# Important to avoid the virtual env using global packages
unset PYTHONPATH
source venv_mn5/bin/activate
python ./vllm_server/run_vllm.py --config config.yaml
```

Override specific configurations using CLI arguments:

```bash
python ./vllm_server/run_vllm.py --config config.yaml --port 8081 --model-path /path/to/model
```

Specify CUDA devices via CLI (overrides config file if set):

```bash
python ./vllm_server/run_vllm.py --config config.yaml --cuda-devices 0,1
```

### YAML Configuration Format

Your `config.yaml` file should look something like this:

```yaml
model_path: "/models"
model_name: "my-model"
port: 8000
cuda_devices: "0,1"  # Optional
other_vllm_arg: value
```
## Argument Precedence

1. CLI arguments (highest priority).
2. YAML configuration file.
3. Default values in the script.



## Connecting Remotely via OpenAI API

If you want to connect to the models from your local machine using the OpenAI API, you can set up an SSH tunnel to the MareNostrum server.
You need to get the target_host with is the ID of your running node.

### Running the SSH Tunnel Script

To create an SSH tunnel, run:

```bash
bash script/bsc_ssh_tunnel.sh <jump_host> <target_host> <ports>
```

**Examples:**

Forward a single port:

```bash
bash ./scripts/bsc_ssh_tunnel.sh mn5-acc-4 as05r1b08 8000
```

Forward multiple ports:

```bash
bash ./scripts/bsc_ssh_tunnel.sh mn5-acc-4 as05r1b08 8000,9000,10000
```

Forward a range of ports:

```bash
bash ./scripts/bsc_ssh_tunnel.sh mn5-acc-4 as05r1b08 8000-8005
```

Once the tunnel is established, you can interact with the vLLM models using the OpenAI API from your local machine.

You can try with the following curl command to see if it works:

```bash
curl http://localhost:8000/v1/completions \
    -H "Content-Type: application/json" \
    -d '{
        "model": "/gpfs/project/bsc02/sla/llm_models/huggingface_models/Llama-2-7b-hf`",
        "prompt": "Barcelona is a",
        "max_tokens": 7,
        "temperature": 0
    }'
```

## Logging

The script logs configuration loading, argument processing, and execution details. Logs will be printed to the console by default.
