import re
import sys
import subprocess
import logging
from pathlib import Path
import yaml
import argparse
import os

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)

def load_config(config_path):
    """Loads a YAML configuration file."""
    try:
        with open(config_path, "r") as f:
            return yaml.safe_load(f) or {}
    except Exception as e:
        logger.error(f"Error loading config: {e}")
        return {}

def get_vllm_arguments():
    """Fetches valid arguments from vLLM's help command."""
    output = subprocess.run(
        ["vllm", "serve", "--help"], capture_output=True, text=True
    ).stdout
    args = re.findall(r"--[\w-]+", output)
    return args

def getting_model_path(config):
    """Constructs the full model path from config."""
    try:
        config["model_path"] = str(Path(config["model_path"]) / config["model_name"])
        del config["model_name"]
    except (TypeError, KeyError):
        pass
    return config

def set_cuda_devices(cuda_devices):
    """Sets the CUDA_VISIBLE_DEVICES environment variable if devices are specified."""
    if cuda_devices:
        os.environ["CUDA_VISIBLE_DEVICES"] = ",".join(map(str, cuda_devices))
        logger.info(f"Using CUDA devices: {os.environ['CUDA_VISIBLE_DEVICES']}")
    else:
        logger.info("No CUDA devices specified; using default device configuration.")

def start_vllm_server(config_path=None, extra_args=None, cuda_devices=None):
    """Starts vLLM server with config file, overridden by CLI args."""
    config = load_config(config_path) if config_path else {}
    config = getting_model_path(config)

    # Merge configs: CLI args override file values
    final_args = {**config, **extra_args} if extra_args else config

    # Determine CUDA devices from CLI or config
    cuda_devices = cuda_devices or config.get("cuda_devices")
    if isinstance(cuda_devices, str):
        cuda_devices = cuda_devices.split(",")

    # Set CUDA devices if provided
    set_cuda_devices(cuda_devices)

    # Prepare command-line arguments
    additional_args = []
    for key, value in final_args.items():
        if isinstance(value, bool):  # Handle flags
            if value:
                additional_args.append(f"--{key.replace('_', '-')}")
        else:
            additional_args.extend([f"--{key.replace('_', '-')}", str(value)])

    logger.info(f"Starting vLLM with args: {additional_args}")  # Debugging output

    command = ["python", "-m", "vllm.entrypoints.openai.api_server"]
    if additional_args:
        command.extend(additional_args)

    subprocess.run(command)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Start vLLM server with YAML config and additional arguments."
    )
    parser.add_argument("--config", type=str, help="Path to YAML config file")
    parser.add_argument("--cuda-devices", type=str, help="Comma-separated list of CUDA devices to use")

    # Parse known and unknown arguments
    args, unknown_args = parser.parse_known_args()

    # Get valid vLLM arguments
    valid_args_list = get_vllm_arguments()

    # Convert unknown args to dictionary format
    extra_args = {}
    key = None
    for item in unknown_args:
        if item.startswith("--") and item in valid_args_list:
            key = item.lstrip("-").replace("-", "_")
            extra_args[key] = True  # Assume flag unless overridden
        elif key:
            extra_args[key] = item
            key = None  # Reset key

    # Override any argument if provided
    for arg_key, arg_value in vars(args).items():
        if arg_value is not None and arg_key != "config" and arg_key != "cuda_devices":
            extra_args[arg_key] = arg_value

    # Handle CUDA devices
    cuda_devices = args.cuda_devices.split(",") if args.cuda_devices else None

    # Start server
    start_vllm_server(config_path=args.config, extra_args=extra_args, cuda_devices=cuda_devices)
