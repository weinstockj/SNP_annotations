#!/bin/bash
snakemake -p --profile slurm -j 140 --rerun-incomplete --keep-going 1>stdout.log 2>stderr.log
# snakemake -p --executor slurm -j 140 --rerun-incomplete 1>stdout.log 2>stderr.log
