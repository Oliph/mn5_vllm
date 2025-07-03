#!/bin/bash
#SBATCH --job-name=vllm_single
#SBATCH --ntasks-per-node=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=80
#SBATCH --gres=gpu:4
#SBATCH --time=01:00:00
#SBATCH --output=logs/slurm_single_%j.out
#SBATCH --error=logs/slurm_single_%j.err

# ----------------------------
# 0. Load environment and enter project directory
# ----------------------------
cd /gpfs/projects/bsc02/sla_projects/vllm_server
gpus_per_task=$(scontrol show job "$SLURM_JOB_ID" | grep -oP 'gres/gpu=\K[0-9]+' | head -n1)

echo "Detected configuration:"
echo "  GRES line      : $gres_line"
echo "  Total GPUs     : $gpus_per_task"

echo "Launching vLLM workload on head node"

srun ./launch_vllm.sh "$gpus_per_task" 1 "$@"
