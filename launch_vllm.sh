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
#   $2        -> pipeline_parallel_size (from SLURM script)
#   $3...$@   → Additional command-line arguments passed
#              from sbatch to the Python workload
#
# --------------------------------------------

echo "[VLLM] Starting workload launch script"

# Check if tensor parallel size was passed
#FIXME: should default to 1 if nothing is passed
tensor_parallel_size=$1
pipeline_parallel_size=$2

if [ -z "$tensor_parallel_size" ]; then
  echo "[VLLM] Error: Missing tensor parallel size argument (expected as \$1)"
  exit 1
fi
if [ -z "$pipeline_parallel_size" ]; then
  echo "[VLLM] Error: Missing pipeline parallel size argument (expected as \$1)"
  exit 1
fi
echo "[VLLM]] Changing to project directory: /gpfs/projects/bsc02/sla_projects/vllm_server"
cd /gpfs/projects/bsc02/sla_projects/vllm_server || {
  echo "[VLLM] Failed to cd into project directory"
  exit 1
}

echo "[VLLM] Purging and loading modules (mkl, intel, python/3.12)"
module purge && module load mkl intel python/3.12

echo "[VLLM] PYTHONPATH BEFORE UNSETTING: $PYTHONPATH"
unset PYTHONPATH

echo "[VLLM] Activating virtual environment: venv_mn5"
source venv_mn5/bin/activate || {
  echo "[VLLM] Failed to activate virtual environment"
  exit 1
}

echo "[VLLM] Launching vLLM server with:"
echo "    --tensor-parallel-size: $tensor_parallel_size"
echo "    --pipeline-parallel-size: $pipeline_parallel_size"
echo "    Additional args: ${@:3}"

python ./vllm_server/run_vllm.py \
  --tensor-parallel-size "$tensor_parallel_size" \
  --pipeline-parallel-size "$pipeline_parallel_size" \
  "${@:3}"
