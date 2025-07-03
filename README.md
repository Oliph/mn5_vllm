
# vLLM Server Launcher for MareNostrum

Reusable launcher for deploying [vLLM](https://github.com/vllm-project/vllm) servers on SLURM-based HPC clusters like MareNostrum (BSC). Supports YAML configuration, CLI overrides, SLURM integration, GPU affinity, and remote access via OpenAI-compatible API.

## Features

- Launch vLLM with YAML-based configs
- CLI arguments override YAML settings
- GPU device selection via `CUDA_VISIBLE_DEVICES`
- Extracts valid `vllm serve` args dynamically
- Usable in SBATCH scripts or directly from Python
- Supports remote OpenAI API access via SSH tunneling

## Installation

### Option 1: From local environment

```bash
module purge && module load mkl intel python/3.12
unset PYTHONPATH  # Avoid global packages
python -m venv venv_mn5
source venv_mn5/bin/activate
pip install -r requirements.txt
```

### Option 2: As Python package (recommended)

To make the launcher reusable across projects:

```bash
git clone https://gitlab.bsc.es/social-link-analytic/vllm_marenostrum.git
cd vllm-marenostrum
pip install -e .
```

This installs the CLI tool:

```bash
vllm-launch --config config/mistral_small_24B-Instruct.yaml --tensor-parallel-size 2
```

## Downloading Hugging Face Models

Models are saved to a shared folder to avoid re-downloading.

```bash
cd $MODEL_FOLDER
bash ./script/hf_dl.sh mistralai/Mistral-Small-24B-Instruct-2501

This will download the model to `$MODEL_FOLDER/Mistral-Small-24B-Instruct-2501`.
It is better to keep that folder common to all project to avoid downloading same models twice as they are very large.

### Hugging Face Authentication

```bash
# Option 1: via env var
export HUGGINGFACE_HUB_TOKEN=your_token

# Option 2: via CLI
huggingface-cli login
```

## Configuration File Example

Your config file should look like this:

```yaml
model_path: "/gpfs/projects/$USER/sla/llm_models/huggingface_models"
model_name: "Mistral-Small-24B-Instruct-2501"
port: 8000
tensor_parallel_size: 4
cuda_devices: "0,1,2,3"
```

## Usage

### SLURM Interactive (1 node, 4 GPUs)

```bash
salloc -A $USER -t 01:00:00 -q $QUEUE -n 1 -c 80 --gres=gpu:4
```

### SLURM Batch Job

Submit a single-node job:

```bash
sbatch -A $USER -t 01:00:00 -q $QUEUE run_scripts/run_single_nodes.sh \
  --config config/mistral_small_24B-Instruct.yaml
```

## Running the Launcher

### With configuration file

```bash
python -m vllm_marenostrum.cli --config config/mistral_small_24B-Instruct.yaml
```

### With CLI overrides

```bash
python -m vllm_marenostrum.cli \
  --config config/mistral_small_24B-Instruct.yaml \
  --port 8081 \
  --tensor-parallel-size 4
```

### Set GPU devices manually

```bash
python -m vllm_marenostrum.cli \
  --config config/mistral_small_24B-Instruct.yaml \
  --cuda-devices 0,1,2,3
```

## Remote Access (OpenAI-compatible)

To connect to your running server from your laptop using the OpenAI API, establish an SSH tunnel.

### Tunnel Script

```bash
bash helpers_scripts/bsc_ssh_tunnel.sh <jump_host> <target_node> <ports>
```

**Examples:**

```bash
# Forward port 8000
bash helpers_scripts/bsc_ssh_tunnel.sh $USER@$NODE $NODE_HOSTNAME 8000
```

### Test locally with curl

```bash
curl http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
        "model": "$MODEL_FOLDER/Mistral-Small-24B-Instruct-2501",
        "prompt": "Barcelona is a",
        "max_tokens": 7,
        "temperature": 0
      }'
```

## Logging

- Logs will appear in the SLURM `.out` and `.err` files when running via `sbatch`.
- All major stages (config loading, CLI parsing, CUDA setup) are logged to `stdout`.

## Developer Notes

Project structure:

```
vllm-marenostrum/
├── config/                      # YAML config files
├── helpers_scripts/            # Tunneling, HF download scripts
├── run_scripts/                # SLURM + Ray + Launcher scripts
├── vllm_marenostrum/           # Main Python launcher package
│   ├── cli.py
│   ├── __init__.py
│   └── vllm_launcher.py
```

Python entry point:

```bash
vllm-launch --config config/mistral_small_24B-Instruct.yaml
```

## Contributing

This project helps run open-source LLMs like Mistral, LLaMA, and Qwen at scale using SLURM on BSC supercomputers. Issues and PRs are welcome.

## License

MIT
