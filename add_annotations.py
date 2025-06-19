import polars as pl
import polars.selectors as cs
import duckdb
import sys
import logging
from utils import *

def get_expected_column_order(variant_columns, bed_extra_columns, AF_columns, encode_names):
    """
    Generate the expected column order for the final dataframe.
    
    Args:
        variant_columns: Base variant columns (chrom, start, end, variant_id, ref, alt)
        bed_extra_columns: Additional columns from the bed file
        AF_columns: Allele frequency columns from 1KG
        encode_names: ENCODE cCRE column names
    
    Returns:
        List of column names in the expected order
    """
    expected_columns = (
        variant_columns +
        bed_extra_columns +
        AF_columns +
        ["ChIP", "Chromatin_accessibility", "QTL", "PWM"] +  # regulomedb columns
        ["am_pathogenicity"] +  # AlphaMissense column
        sorted(encode_names)  # ENCODE columns in sorted order
    )
    return expected_columns

bed_file           = sys.argv[1]
AF_1KG_file        = sys.argv[2]
regulomedb_file    = sys.argv[3]
AlphaMissense_file = sys.argv[4]
ENCODE_cCRE_file   = sys.argv[5]
output_file        = sys.argv[6]
# bed_file = "/data/abattle4/jweins17/annotations/output/chr1_21002467_22858108/variant_list_ccre_annotated.bed"
# AF_1KG_file = "/data/abattle4/jweins17/annotations/input/1KG_AF/CCDG_1KG_chr1.parquet"
# regulomedb_file = "/data/abattle4/jweins17/annotations/input/regulomedb/regulomedb_with_id.parquet"
# AlphaMissense_file = "/data/abattle4/jweins17/annotations/input/AlphaMissense/AlphaMissense_hg38.parquet"
# ENCODE_cCRE_file = "/data/abattle4/jweins17/annotations/input/ENCODE_cCRE/GRCh38-cCREs.bed"

logging.basicConfig(
        format='%(asctime)s %(message)s', 
        datefmt='%m/%d/%Y %I:%M:%S %p', 
        level=logging.INFO, 
        stream=sys.stdout
)

if __name__ == "__main__":

    logging.info(f"Now running with arguments\n 1. {bed_file}\n 2. {AF_1KG_file}\n 3. {regulomedb_file}\n 4. {AlphaMissense_file}\n 5. {ENCODE_cCRE_file}\n 6. {output_file}\n")

    with open(bed_file, 'r') as f:
        first_line = f.readline().strip().replace("#", "").split("\t")

    variant_columns = ["chrom", "start", "end", "variant_id", "ref", "alt"]
    headers =  variant_columns + list(filter(lambda x: x != "", first_line))

    bed = read_bed(bed_file, headers)

    MIN_POS = bed.select("start").min().collect(streaming = True).item()
    MAX_POS = bed.select("end").max().collect(streaming = True).item()
    ACTIVE_CHR = bed.select("chrom").first().collect(streaming = True).item()

    logging.info("Loaded bed file")

    AF_1KG = pl.scan_parquet(AF_1KG_file). \
            with_columns(cs.contains("AF_").cast(pl.Float32))
    
    # Get AF column names for expected column ordering
    AF_columns = [col for col in AF_1KG.collect_schema().names() if col.startswith("AF_")]

    logging.info("Loaded 1KG file")

    regulomedb = pl.scan_parquet(regulomedb_file). \
            select(["ID", "ChIP", "Chromatin_accessibility", "QTL", "PWM"]). \
            rename({"ID": "variant_id"})

    logging.info("Loaded regulome file")

    AlphaMissense = pl.scan_parquet(AlphaMissense_file). \
            select(["variant_id", "am_pathogenicity"])

    logging.info("Loaded AlphaMissense file")

    cCRE = read_cCRE(ENCODE_cCRE_file, ACTIVE_CHR, MIN_POS, MAX_POS)

    logging.info("Loaded ENCODE cCRE file")

    logging.info("Now merging")

    dfm = merge_1KG(bed, AF_1KG)

    dfm = merge_regulomedb(dfm, regulomedb)

    dfm = merge_AlphaMissense(dfm, AlphaMissense)

    print(dfm.head())

    print(cCRE.head())

    dfm = duckdb.sql("SELECT * FROM dfm LEFT JOIN cCRE ON dfm.chrom = cCRE.chrom AND dfm.start >= cCRE.start AND dfm.end <= cCRE.end").pl().drop(["chrom_1", "start_1", "end_1"])

    print(dfm.head())

    encode_names = [
            "pELS", 
            "CA-CTCF", 
            "CA", "CA-TF", 
            "dELS", 
            "TF", 
            "CA-H3K4me3", 
            "PLS"
        ]

    # Get bed extra columns (excluding variant columns)
    bed_extra_columns = [col for col in headers if col not in variant_columns]
    
    # Generate expected column order
    expected_columns = get_expected_column_order(variant_columns, bed_extra_columns, AF_columns, encode_names)

    current_names = dfm.columns 
    encode_diff = list(set(encode_names) - set(current_names))

    dfm = dfm.lazy()

    for name in encode_diff:
        dfm = dfm.with_columns(pl.lit(0).alias(name))

    dfm = dfm. \
        with_columns(
            cs.by_name(
                encode_names,
                require_all = True
            ). 
            cast(pl.Boolean).
            fill_null(False) # impute
        ). \
        unique(). \
        sort("start"). \
        select([col for col in expected_columns if col in dfm.collect_schema().names()])

    logging.info("Now writing")
    dfm.sink_parquet(output_file)
