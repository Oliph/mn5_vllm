#!/bin/bash
## --------------------------------------------
# Workload Launcher Script
#
# This script is designed to be called via `srun` from
# `run_cluster.sh`. It performs the necessary environment
# setup and runs the vLLM workload.
#
# Arguments:
#   $1        → Tensor parallel size (from SLURM script)
#   $2...$@   → Additional command-line arguments passed
#              from sbatch to the Python workload
#
# --------------------------------------------

echo "[launch_vllm.sh] Starting workload launch script"
#
# Check if tensor parallel size was passed
tensor_parallel_size=$1
if [ -z "$tensor_parallel_size" ]; then
  echo "Error: Missing tensor parallel size argument (expected as \$1)"
  exit 1
fi
echo "Changing to project directory: /gpfs/projects/bsc02/sla_projects/vllm_server"
cd /gpfs/projects/bsc02/sla_projects/vllm_server || {
  echo "Failed to cd into project directory"
  exit 1
}

echo "Purging and loading modules (mkl, intel, python/3.12)"
module purge && module load mkl intel python/3.12

echo "Unsetting PYTHONPATH"
unset PYTHONPATH

echo "Activating virtual environment: venv_mn5"
source venv_mn5/bin/activate || {
  echo "Failed to activate virtual environment"
  exit 1
}

echo "Launching vLLM server with:"
echo "    --tensor-parallel-size: $tensor_parallel_size"
echo "    Additional args: ${@:2}"

python ./vllm_server/run_vllm.py --tensor-parallel-size $tensor_parallel_size --config config.yaml
