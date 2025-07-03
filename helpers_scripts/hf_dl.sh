#!/bin/bash
# Load appropriate modules and activate virtualenv
module purge && module load mkl intel python/3.12 # 3.12 for vllm
source venv_mn5/bin/activate
unset PYTHONPATH # Important to avoid the virtual env using local packages

# Check if a model name is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <model_name>"
  exit 1
fi

MODEL_NAME="$1"

# Extract the last part of the model name
FOLDER_NAME=$(basename "$MODEL_NAME")

# Define directories
LOCAL_DIR="./huggingface_models/$FOLDER_NAME"
CACHE_DIR="./cache"

# Run the download command
huggingface-cli download "$MODEL_NAME" --local-dir "$LOCAL_DIR" --cache-dir "$CACHE_DIR"
