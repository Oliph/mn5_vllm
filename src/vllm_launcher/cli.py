
import argparse
from .vllm_launcher import get_vllm_arguments, launch_vllm_server

def main():
    parser = argparse.ArgumentParser(
        description="Start vLLM server with YAML config and additional arguments."
    )
    parser.add_argument("--config", type=str, help="Path to YAML config file")
    parser.add_argument(
        "--cuda-devices", type=str, help="Comma-separated list of CUDA devices to use"
    )
    # Allow CLI to supply the model override.
    parser.add_argument(
        "--model", type=str, help="Path to the model directory (overrides config)"
    )

    # Parse known and unknown arguments.
    args, unknown_args = parser.parse_known_args()

    # Get valid vLLM arguments.
    valid_args_list = get_vllm_arguments()

    # Convert unknown arguments to dictionary format.
    extra_args = {}
    key = None
    for item in unknown_args:
        if item.startswith("--") and item in valid_args_list:
            key = item.lstrip("-").replace("-", "_")
            extra_args[key] = True  # Assume flag unless overridden.
        elif key:
            extra_args[key] = item
            key = None

    # Override any argument from the known arguments (except for config and cuda_devices).
    for arg_key, arg_value in vars(args).items():
        if arg_value is not None and arg_key not in ["config", "cuda_devices"]:
            extra_args[arg_key] = arg_value

    # Handle CUDA devices.
    cuda_devices = args.cuda_devices.split(",") if args.cuda_devices else None

    # Start the vLLM server.
    launch_vllm_server(config_path=args.config, extra_args=extra_args, cuda_devices=cuda_devices)

if __name__ == "__main__":
    main()


