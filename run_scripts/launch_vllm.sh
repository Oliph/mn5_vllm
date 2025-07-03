#!/bin/bash
# --------------------------------------------
# Workload Launcher Script (for SLURM SBATCH)
# --------------------------------------------
# Arguments:
#   $1        → tensor_parallel_size
#   $2        → pipeline_parallel_size (optional, default=1)
#   $3...$@   → Additional args passed to the launcher
# --------------------------------------------

echo "[VLLM] Starting vLLM launcher script..."

# Read input args
TP_SIZE=${1:-1}
PIPELINE_SIZE=${2:-1}
shift 2

# Change to project root
cd /gpfs/projects/bsc02/sla_projects/vllm_server || {
  echo "[VLLM] ERROR: Failed to change directory"
  exit 1
}

# Load modules and activate environment
module purge && module load mkl intel python/3.12
unset PYTHONPATH
source venv_mn5/bin/activate

echo "[VLLM] Environment ready. Launching vllm_marenostrum..."

# Run the vLLM launcher (installed via pip)
vllm-launch --tensor-parallel-size "$TP_SIZE" \
  --pipeline-parallel-size "$PIPELINE_SIZE" \
  "$@"
