import polars as pl
import polars.selectors as cs

def read_cCRE(path, ACTIVE_CHR, MIN_POS, MAX_POS) -> pl.DataFrame:

    cCRE = pl.scan_csv(
            path,
            has_header=False,
            separator="\t",
            new_columns=["chrom", "start", "end", "accession1", "accession2", "cCRE_label"]
        ). \
        filter(
                (pl.col("chrom") == ACTIVE_CHR) & 
                (pl.col("start") > MIN_POS) & 
                (pl.col("end") < MAX_POS)
        ). \
        with_columns(
            pl.lit(True).alias("value")
        ). \
        select(["chrom", "start", "end", "cCRE_label", "value"]). \
        collect(streaming = True). \
        pivot(
            "cCRE_label",
            index = ["chrom", "start", "end"],
            values = "value"
        ).lazy()

    cCRE = cCRE. \
        with_columns(
            # pl.col(
            #     ["pELS", "CA-CTCF", "CA", "CA-TF", "dELS", "TF", "CA-H3K4me3", "PLS"]
            # ). \
            cs.by_name(
                "pELS", "CA-CTCF", "CA", "CA-TF", "dELS", "TF", "CA-H3K4me3", "PLS",
                require_all = False
            ). \
            cast(pl.Boolean). \
            fill_null(False) # impute
        ). \
        unique(). \
        collect(streaming = True)

    return cCRE

def read_bed(bed_file, headers) -> pl.DataFrame:

    bed = pl.scan_csv(
            bed_file,
            has_header=False,
            separator="\t",
            new_columns=headers,
            comment_prefix="#"
        ).with_columns(
            cs.exclude(
                "chrom",
                "start",
                "end",
                "variant_id", 
                "ref", 
                "alt"
            ).cast(pl.Int8)
        )

    return bed

def merge_regulomedb(dfm, regulomedb) -> pl.DataFrame:

    dfm = dfm.join(
                regulomedb, 
                on = "variant_id", 
                how = "left"
            ). \
            with_columns(
                pl.col(
                    "ChIP",
                    "Chromatin_accessibility",
                    "QTL",
                    "PWM"
                ).fill_null(False)
            ) # impute

    return dfm

def merge_AlphaMissense(dfm, AlphaMissense) -> pl.DataFrame:

    dfm = dfm.join(
                AlphaMissense,
                on = "variant_id",
                how = "left"
            ). \
            with_columns(
                pl.col("am_pathogenicity").fill_null(0)
            ). \
            collect(streaming = True) # impute

    return dfm

def merge_1KG(bed, AF_1KG) -> pl.DataFrame:

    dfm = bed.join(
            AF_1KG, 
            on = "variant_id", 
            how = "left"
          ). \
          with_columns(
                cs.contains("AF_").fill_null(1e-7) # impute
          ) 

    return dfm

