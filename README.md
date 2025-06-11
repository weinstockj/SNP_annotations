# Genomic Variant Annotation Pipeline

A Snakemake workflow for comprehensive genomic variant annotation using multiple data sources including regulatory elements, conservation scores, pathogenicity predictions, and population genetics data.

## Overview

This pipeline processes genomic variants in LD (Linkage Disequilibrium) blocks and annotates them with:
- **Cell-type specific regulatory elements** from single-cell atlas data
- **Conservation scores** from Zoonomia project (RoCCs and UCEs)
- **Regulatory information** from RegulomeDB
- **Pathogenicity predictions** from AlphaMissense
- **ENCODE cCRE** (candidate Cis-Regulatory Elements)
- **Population allele frequencies** from 1000 Genomes Project

## Requirements

### Software Dependencies
- Snakemake
- bedtools
- htslib
- DuckDB
- Python packages:
  - polars
  - pandas
  - yaml
- Conda/Mamba environments (see Environment Setup below)

### Environment Setup

This pipeline requires two conda/mamba environments that can be automatically created using the provided requirements files:

#### 1. Snakemake Environment
Create the main environment for running the Snakemake workflow:

```bash
# Using conda
conda create --name snakemake --file requirements_snakemake.txt

# Using mamba (recommended for faster installation)
mamba create --name snakemake --file requirements_snakemake.txt
```

#### 2. Parquet Environment 
Create the environment for data processing steps:

```bash
# Using conda
conda create --name parquet --file requirements_parquet.txt

# Using mamba (recommended for faster installation)  
mamba create --name parquet --file requirements_parquet.txt
```

#### Activating Environments

The Snakemake workflow will automatically activate the appropriate environments. However, you can manually activate them as needed:

```bash
# Activate snakemake environment to run the workflow
conda activate snakemake

# The parquet environment is automatically activated by rules that process data
# But you can manually activate it for testing:
conda activate parquet
```

**Note**: Make sure to update the paths to your conda/mamba activation scripts in `config.yaml`:
```yaml
CONDA: "/path/to/your/conda.sh"
MAMBA: "/path/to/your/mamba.sh"
```

### Input Data Sources

The pipeline requires the following input datasets configured in `config.yaml`:

1. **LD Blocks**: Pre-defined linkage disequilibrium blocks file
   - Estimates can be downloaded [here](https://github.com/jmacdon/LDblocks_GRCh38/tree/master/data)

2. **Regulatory Elements**:
   - **RoCC** (Regions of Conserved Constraint) from Zoonomia: [https://zoonomiaproject.org/](https://zoonomiaproject.org/)
   - **UCE** (Ultra-Conserved Elements) from Zoonomia: [https://zoonomiaproject.org/](https://zoonomiaproject.org/)
   - **Cell-type specific regulatory regions**: Single-cell atlas data from [Zhang et al. 2021](https://www.nature.com/articles/s41586-021-03604-1)
   - Download: 
   `bash
    wget https://cgl.gi.ucsc.edu/data/cactus/zoonomia-2021-track-hub/hg38/RoCCs.bed.gz
    wget https://cgl.gi.ucsc.edu/data/cactus/zoonomia-2021-track-hub/hg38/zooUCEs.bed.gz
    wget https://cgl.gi.ucsc.edu/data/cactus/zoonomia-2021-track-hub/hg38/UNICORNs.bed.gz
    `

3. **Regulatory Databases**:
   - **RegulomeDB**: [https://regulomedb.org/regulome-help/](https://regulomedb.org/regulome-help/) - Download bulk data
   - `bash
    wget https://www.encodeproject.org/files/ENCFF250UJY/@@download/ENCFF250UJY.tsv
    ln -s ENCFF250UJY.tsv regulomedb.tsv
   `
   - **dbSNP**: [https://www.ncbi.nlm.nih.gov/snp/](https://www.ncbi.nlm.nih.gov/snp/) - NCBI dbSNP database

4. **Pathogenicity Scores**:
   - **AlphaMissense**: [https://github.com/google-deepmind/alphamissense](https://github.com/google-deepmind/alphamissense) - Download predictions

5. **Ancestry stratified allele frequencies**:
   - **1000 Genomes Project**: [https://www.internationalgenome.org/data/](https://www.internationalgenome.org/data/) - Allele frequency data

6. **ENCODE Data**:
   - **cCREs** (candidate Cis-Regulatory Elements): [https://screen.encodeproject.org/](https://screen.encodeproject.org/) - ENCODE SCREEN database
   - `bash wget https://downloads.wenglab.org/Registry-V4/GRCh38-cCREs.bed`

## Configuration

Edit `config.yaml` to specify paths to your input data:

```yaml
LD_blocks_file: "path/to/LD_blocks.bed"
RoCC: "path/to/RoCCs.bed.gz"
UCE: "path/to/zooUCEs.bed.gz"
ADULT_CELL_TYPE_DIR: "path/to/cell_type_beds"
REGULOME_DB_PATH: "path/to/regulomedb.tsv"
# ... (see config.yaml for full configuration)
```

## Usage

### Running the Complete Pipeline

```bash
# Run with cluster execution (SLURM)
bash run_cluster.sh

# Or run locally
snakemake -p -j <num_cores> --rerun-incomplete
```

### Key Output Files

- `{OUTPUT_DIR}/all_variants_annotated_complete.parquet`: Complete annotated variant dataset
- `{OUTPUT_DIR}/all_variants.bed`: Combined BED file of all variants
- `{OUTPUT_DIR}/{BLOCK}/variant_list_ccre_annotated_complete.parquet`: Per-block annotated variants

## Pipeline Workflow

### Step 1: Cell-type Regulatory Annotation (`ccre` rule)
- Converts variant lists to BED format
- Uses bedtools to annotate variants with:
  - Cell-type specific regulatory elements
  - RoCC conservation scores
  - UCE ultra-conserved elements

### Step 2: Database Preparation
- **`convert_regulome`**: Converts RegulomeDB TSV to Parquet format
- **`setid_regulome`**: Adds variant IDs using dbSNP reference
- **`convert_alpha`**: Processes AlphaMissense pathogenicity scores

### Step 3: Comprehensive Annotation (`add_more_annotations` rule)
- Merges variants with:
  - 1000 Genomes allele frequencies
  - RegulomeDB regulatory annotations
  - AlphaMissense pathogenicity scores
  - ENCODE cCRE elements

### Step 4: Data Collation
- **`collate_annotations`**: Combines all per-block annotations
- **`mega_bed`**: Creates unified BED file of all variants

## Scripts Description

### Core Scripts

- **`add_annotations.py`**: Main annotation script that merges variant data with multiple annotation sources
- **`collate_annotations.py`**: Combines multiple parquet files into a single dataset
- **`utils.py`**: Utility functions for data processing and merging operations

### Key Functions in `utils.py`

- `read_cCRE()`: Reads and processes ENCODE cCRE data
- `read_bed()`: Parses BED files with proper column typing
- `merge_regulomedb()`: Joins RegulomeDB annotations
- `merge_AlphaMissense()`: Adds pathogenicity predictions
- `merge_1KG()`: Incorporates population allele frequencies

## Output Annotations

Each variant is annotated with:

### Regulatory Elements
- Cell-type specific accessibility (multiple cell types)
- RoCC conservation scores
- UCE ultra-conserved element overlap

### Regulatory Information
- ChIP-seq evidence (`ChIP`)
- Chromatin accessibility (`Chromatin_accessibility`)
- QTL associations (`QTL`)
- PWM motif matches (`PWM`)

### Pathogenicity
- AlphaMissense pathogenicity score (`am_pathogenicity`)

### ENCODE cCREs
- Various cCRE types: `pELS`, `CA-CTCF`, `CA`, `CA-TF`, `dELS`, `TF`, `CA-H3K4me3`, `PLS`

### Population Genetics
- Allele frequencies across 1000 Genomes populations (multiple `AF_*` columns)

## Resource Requirements

- Memory: 3-18GB depending on the rule
- Time: 1-8 hours per rule
- Storage: Varies based on input data size

### Log Files

- `stdout.log`: Standard output from Snakemake execution
- `stderr.log`: Error messages and warnings
- Individual rule logs in `logs/` directory

## Citation

If you use this pipeline in your research, please cite the relevant data sources:
- RegulomeDB
- AlphaMissense
- ENCODE Project
- Zoonomia Consortium
- 1000 Genomes Project

## Contact

For questions or issues, please contact Josh Weinstock.
