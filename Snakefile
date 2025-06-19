import pandas as pd 
import os
import yaml

cfg = yaml.safe_load(open("config.yaml"))

## CONFIG -----------------------------------------------------------------------------
# one line per region
LD_blocks_file = cfg["LD_blocks_file"]

# No X chromsome!
CHROMS, = glob_wildcards("../input/20201028_CCDG_14151_B01_GRM_WGS_2020-08-05_{ID}.recalibrated_variants.vcf.gz")

# BED FILES
RoCC = cfg["RoCC"]
UCE = cfg["UCE"]

ADULT_CELL_TYPE_DIR = cfg["ADULT_CELL_TYPE_DIR"]
FETAL_CELL_TYPE_DIR = cfg["FETAL_CELL_TYPE_DIR"]

REGULOME_DB_PATH = cfg["REGULOME_DB_PATH"]
dbSNP_PATH = cfg["dbSNP_PATH"]

ALPHA_MISSENSE_PATH = cfg["ALPHA_MISSENSE_PATH"]
ENCODE_cCRE_PATH = cfg["ENCODE_cCRE_PATH"]
AF_1KG_PREFIX = cfg["AF_1KG_PREFIX"]
LD_BLOCK_DIR = cfg["LD_BLOCK_DIR"]
OUTPUT_DIR = cfg["OUTPUT_DIR"]

## -----------------------------------------------------------------------------------

ADULT_CELL_TYPES, = glob_wildcards(f"{ADULT_CELL_TYPE_DIR}/{{ID}}.bed")
ADULT_CELL_TYPES = [os.path.basename(x) for x in ADULT_CELL_TYPES]
# FETAL_CELL_TYPES, = glob_wildcards(f"{FETAL_CELL_TYPE_DIR}/{{ID}}.bed")
# ALL_CELL_TYPES = ADULT_CELL_TYPES + FETAL_CELL_TYPES
ALL_CELL_TYPES = ADULT_CELL_TYPES
CELL_TYPE_PATHS_CONTAINER = dict() 

for cell_type in ALL_CELL_TYPES:
    CELL_TYPE_PATHS_CONTAINER[cell_type] = f"{ADULT_CELL_TYPE_DIR}/{cell_type}.bed" if "Fetal" not in cell_type else f"{FETAL_CELL_TYPE_DIR}/{cell_type}.bed"

CELL_TYPE_PATHS = list(CELL_TYPE_PATHS_CONTAINER.values())

# print(CELL_TYPE_PATHS_CONTAINER)

# -------------------------------------------------------------------------------------
if not os.path.isfile(LD_blocks_file):
    IOError(f"LD blocks file {LD_blocks_file} does not exist")

LD_blocks = pd.read_table(LD_blocks_file)
LD_blocks["block"] = LD_blocks["chr"].astype(str) + "_" + LD_blocks["start"].astype(str) + "_" + LD_blocks["end"].astype(str)

rule all:
    input:
        expand(os.path.join(OUTPUT_DIR, "{BLOCK}", "variant_list_ccre_annotated.bed"), BLOCK = LD_blocks.block.values),
        os.path.join(OUTPUT_DIR, "all_variants.bed"),
        os.path.join(os.path.dirname(REGULOME_DB_PATH), "regulomedb.parquet"),
        os.path.join(os.path.dirname(REGULOME_DB_PATH), "regulomedb_with_id.parquet"),
        os.path.join(os.path.dirname(ALPHA_MISSENSE_PATH), "AlphaMissense_hg38.parquet"),
        expand(os.path.join(OUTPUT_DIR, "{BLOCK}", "variant_list_ccre_annotated_complete.parquet"), BLOCK = LD_blocks.block.values),
        os.path.join(OUTPUT_DIR, "all_variants_annotated_complete.parquet")

rule ccre:
    output:
        annotated = os.path.join(OUTPUT_DIR, "{BLOCK}", "variant_list_ccre_annotated.bed")
    params:
        out_dir = os.path.join(OUTPUT_DIR, "{BLOCK}"),
        variant_list = os.path.join(LD_BLOCK_DIR, "{BLOCK}", "variant_list.tsv"),
        variant_list_bed = os.path.join(OUTPUT_DIR, "{BLOCK}", "variant_list.bed.gz")
    output:
        annotated = os.path.join(OUTPUT_DIR, "{BLOCK}", "variant_list_ccre_annotated.bed")
    threads: 1 
    resources:
        mem = "3G",
        partition = "shared",
        time = "8:00:00"
    shell:
        """
        mkdir -p {params.out_dir}
        module load bedtools
        module load htslib
        tail -n+2 {params.variant_list} | awk '{{print $1, $2-1, $2, $3, $4, $5}}' OFS="\t" | bgzip -c > {params.variant_list_bed}

        bedtools annotate -i {params.variant_list_bed} -files {CELL_TYPE_PATHS} {RoCC} {UCE} -names {ALL_CELL_TYPES} RoCC UCE -counts > {output.annotated}
        """

rule convert_regulome:
    input:
        REGULOME_DB_PATH
    output:
        os.path.join(os.path.dirname(REGULOME_DB_PATH), "regulomedb.parquet")
    threads: 1 
    resources:
        mem = "6G",
        partition = "shared",
        time = "2:00:00"
    shell:
        """
        source .venv/bin/activate

        python -c 'import polars as pl; pl.scan_csv("{input}", has_header=True, separator = "\t").sink_parquet("{output}")'
        """

rule setid_regulome:
    input:
        os.path.join(os.path.dirname(REGULOME_DB_PATH), "regulomedb.parquet")
    output:
        os.path.join(os.path.dirname(REGULOME_DB_PATH), "regulomedb_with_id.parquet")
    threads: 1 
    resources:
        mem = "6G",
        partition = "shared",
        time = "2:00:00"
    shell:
        """
        source .venv/bin/activate 

        python -c 'import polars as pl; df = pl.scan_parquet("{input}").rename({{"rsid" : "RSID"}}); lk = pl.scan_parquet("{dbSNP_PATH}/*.parquet"); df.join(lk, how = "inner", on = "RSID").sink_parquet("{output}")'
        """

rule convert_alpha:
    input:
        ALPHA_MISSENSE_PATH
    output:
        os.path.join(os.path.dirname(ALPHA_MISSENSE_PATH), "AlphaMissense_hg38.parquet")
    threads: 1 
    resources:
        mem = "15G",
        partition = "shared",
        time = "2:00:00"
    shell:
        """
        source .venv/bin/activate 

        python -c 'import polars as pl; pl.read_csv("{input}", has_header=True, separator = "\t", skip_rows=3, columns = ["#CHROM", "POS", "REF", "ALT", "am_pathogenicity"]).with_columns(pl.concat_str([pl.col("#CHROM"), pl.col("POS"), pl.col("REF"), pl.col("ALT")], separator = "_").alias("variant_id")).write_parquet("{output}")'
        """

rule add_more_annotations:
    input:
        bed = os.path.join(OUTPUT_DIR, "{BLOCK}", "variant_list_ccre_annotated.bed"),
        regulome = os.path.join(os.path.dirname(REGULOME_DB_PATH), "regulomedb_with_id.parquet"),
        AlphaMissense = os.path.join(os.path.dirname(ALPHA_MISSENSE_PATH), "AlphaMissense_hg38.parquet"),
        ENCODE_cCRE = ENCODE_cCRE_PATH
    output:
        os.path.join(OUTPUT_DIR, "{BLOCK}", "variant_list_ccre_annotated_complete.parquet")
    params:
        AF = lambda w: AF_1KG_PREFIX + LD_blocks.chr[LD_blocks.block == w.BLOCK].values[0] + ".parquet"
    threads: 2
    resources:
        mem = "18000",
        partition = "shared",
        time = "1:00:00"
    shell:
        """
        source .venv/bin/activate 

        python add_annotations.py {input.bed} {params.AF} {input.regulome} {input.AlphaMissense} {input.ENCODE_cCRE} {output}
        """

rule collate_annotations:
    input:
        expand(os.path.join(OUTPUT_DIR, "{BLOCK}", "variant_list_ccre_annotated_complete.parquet"), BLOCK = LD_blocks.block.values)
    output:
        os.path.join(OUTPUT_DIR, "all_variants_annotated_complete.parquet")
    params:
        input_string = lambda w: ", ".join([f"'{x}'" for x in rules.collate_annotations.input]) 
    threads: 1
    resources:
        mem = "18000",
        partition = "shared",
        time = "2:00:00"
    shell:
        """
        duckdb -c "COPY (SELECT * FROM read_parquet([{params.input_string}], union_by_name=true)) TO '{output}' (FORMAT PARQUET, ROW_GROUP_SIZE 100_000);"
        """

rule mega_bed:
    input:
        expand(os.path.join(OUTPUT_DIR, "{BLOCK}", "variant_list_ccre_annotated.bed"), BLOCK = LD_blocks.block.values)
    output:
        os.path.join(OUTPUT_DIR, "all_variants.bed")
    threads: 1
    resources:
        mem = "12000",
        partition = "shared",
        time = "6:00:00"
    shell:
        """
        module load bedtools
        module load htslib
        cat {input} | sort -k1,1 -k2,2n | bgzip -c > {output}
        """
