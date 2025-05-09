import pandas as pd
import csv
import warnings
import gzip
import sys


def removal_check(file_path, cleaned_input, filtered_variants_file):
    df = load_df(file_path)
    df = df.drop_duplicates()
    samples_len = len(df["sample_id"].unique())

    df, major_cn_zero = remove_major_cn_zero(df)

    group_transform = df.groupby(df["mutation_id"])["sample_id"].transform("size")
    not_present_muts = df.loc[group_transform < samples_len]
    duplicates = df.loc[group_transform > samples_len]

    report_on_partial_presence_and_dups(duplicates, not_present_muts)

    df = df.loc[group_transform == samples_len]
    df.to_csv(cleaned_input, sep="\t", index=False)

    not_present_muts["filter_reason"] = "Not present in all samples."
    duplicates["filter_reason"] = "Mutation id is duplicated."
    major_cn_zero["filter_reason"] = "Major copy number <= 0."

    filtered_var_df = pd.concat([major_cn_zero, not_present_muts, duplicates])

    filtered_var_df.to_csv(filtered_variants_file, sep="\t", index=False)


def report_on_partial_presence_and_dups(duplicates, not_present_muts):
    num_duplicates = len(duplicates)
    num_duplicates_unique = len(duplicates["mutation_id"].unique())
    num_not_present_in_all = len(not_present_muts)
    num_not_present_in_all_unique = len(not_present_muts["mutation_id"].unique())

    if num_duplicates > 0:
        if num_duplicates == 1:
            pl = ""
        else:
            pl = "s"
        if num_duplicates_unique == 1:
            pl_2 = ""
        else:
            pl_2 = "s"
        print(
            "Removing {} duplicate mutation ID{}, {} unique ID{}.".format(
                num_duplicates,
                pl,
                num_duplicates_unique,
                pl_2,
            )
        )
    if num_not_present_in_all > 0:
        if num_not_present_in_all == 1:
            pl = ("", "is")
        else:
            pl = ("s", "are")
        if num_not_present_in_all_unique == 1:
            pl_2 = ""
        else:
            pl_2 = "s"
        print(
            "Removing {} mutation{} that {} not present in all samples, {} unique ID{}.".format(
                num_not_present_in_all,
                pl[0],
                pl[1],
                num_not_present_in_all_unique,
                pl_2,
            )
        )


def remove_major_cn_zero(df):
    major_cn_zero = df.loc[df["major_cn"] <= 0].copy()
    num_dels = len(major_cn_zero)
    if num_dels > 0:
        print("Removing {} mutations with major copy number zero".format(num_dels))
    df = df.loc[df["major_cn"] > 0]
    return df, major_cn_zero


def load_df(file_path):

    try:
        with open(file_path, "r") as csv_file:
            dialect = csv.Sniffer().sniff(csv_file.readline())
            csv_delim = str(dialect.delimiter)
    except UnicodeDecodeError:
        with gzip.open(file_path, "rt") as csv_file:
            dialect = csv.Sniffer().sniff(csv_file.readline())
            csv_delim = str(dialect.delimiter)

    if csv_delim != "\t":
        warnings.warn(
            "Input should be tab-delimited, supplied file is delimited by {delim}\n"
            "Will attempt parsing with the current delimiter, {delim}\n".format(delim=repr(csv_delim)),
            stacklevel=2,
            category=UserWarning,
        )
    return pd.read_csv(file_path, sep=csv_delim)


if __name__ == "__main__":
    with open(snakemake.log["stdout"], "w") as out_log, open(snakemake.log["stderr"], "w") as err_log:
        sys.stderr = err_log
        sys.stdout = out_log
        removal_check(snakemake.input["raw"], snakemake.output["corrected"], snakemake.output["filtered"])
