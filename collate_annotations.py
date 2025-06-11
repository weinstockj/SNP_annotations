import polars as pl 
import sys
import os
import logging

logging.basicConfig(format='%(asctime)s %(message)s', datefmt='%m/%d/%Y %I:%M:%S %p', level=logging.INFO, stream=sys.stdout)

arg_len = len(sys.argv)
output_file = sys.argv[arg_len - 1]
input_files = sys.argv[1:(arg_len - 1)]

logging.info(f"Input files: {input_files[0:5]}...")

inputs = pl.scan_parquet(input_files)

logging.info(f"Now writing to {output_file}")
inputs.sink_parquet(output_file)
