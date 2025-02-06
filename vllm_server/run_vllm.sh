#!/bin/bash

ROOT_FOLDER=/gpfs/projects/bsc02/sla_projects/demo-sim-health
PATIENT_CONFIG_PATH="./config/patient_model.yaml"
PRACTITIONER_CONFIG_PATH="./config/practitioner_model.yaml"
MODEL_FOLDER="/gpfs/projects/bsc02/llm_models/huggingface_models"
MODEL_NAME=Mistral-Small-24B-Instruct-2501/
GPU_PER_SERVER=2

# CD to folder
cd $ROOT_FOLDER

# Load appropriate modules and activate virtualenv
module purge && module load mkl intel python/3.12
# Important to avoid the virtual env using local packages
unset PYTHONPATH                                  
source venv_mn5/bin/activate

echo "Starting the servers"
export CUDA_VISIBLE_DEVICES=0,1
  vllm serve $MODEL_FOLDER/$MODEL_NAME --port 8000 --tensor-parallel-size $GPU_PER_SERVER &
 
export CUDA_VISIBLE_DEVICES=2,3
  vllm serve $MODEL_FOLDER/$MODEL_NAME --port 8001 --tensor-parallel-size $GPU_PER_SERVER &
