from setuptools import setup, find_packages

setup(
    name="vllm_marenostrum",
    version="0.1.0",
    description="Reusable vLLM server launcher for SLURM/HPC",
    long_description=open("README.md").read(),
    long_description_content_type="text/markdown",
    author="Olivier Philippe",
    author_email="olivier.philippe@gmail.com",
    packages=find_packages(),
    install_requires=[
        "PyYAML",
    ],
    entry_points={
        "console_scripts": [
            "vllm-launch=vllm_launcher.cli:main",
        ]
    },
    classifiers=[
        "Programming Language :: Python :: 3",
        "Operating System :: OS Independent",
    ],
    python_requires=">=3.12",
)
