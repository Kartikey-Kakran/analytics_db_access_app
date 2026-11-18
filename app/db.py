from pathlib import Path
import duckdb

PROJECT_DIR = Path(__file__).resolve().parent.parent


TABLE_GROUPS = {
    "REPLICA survey data": {
        "family_details_rep": (
            "full_replica_data/family_details_rep_all.parquet"
        ),
        "loan_details_rep": (
            "full_replica_data/loan_details_rep_all.parquet"
        ),
        "migrated_details_rep": (
            "full_replica_data/migrated_details_rep_all.parquet"
        ),
        "cp_main_rep": (
            "full_replica_data/survey_data_CP_2026_rep_all.parquet"
        ),
    },
    # Each Parquet filename becomes its SQL table name automatically.
    "Sub tables": {
        path.stem: (str(path.relative_to(PROJECT_DIR)), None)
        for path in sorted(
            (PROJECT_DIR / "sub_table_replica").glob("*.parquet")
        )
    },
    "Main Survey Data":{
        "family_details_main": (
            "raw_data_input_files/family_details.parquet"
        ),
        "loan_details_main":(
            "raw_data_input_files/loan_details.parquet"
        ),
        "migrated_details_main":(
            "raw_data_input_files/migrated_details.parquet"
        ),
        "cp_main":(
            "raw_data_input_files/survey_data_CP_2026.parquet"
        )
    }
}

# Flat mapping retained for callers that need the complete table-name list.
TABLE_FILES = {
    table_name: files
    for group_tables in TABLE_GROUPS.values()
    for table_name, files in group_tables.items()
}


def connect():
    con = duckdb.connect(":memory:")

    for table_name, file_spec in TABLE_FILES.items():
        # Accept either (parquet_path, csv_path) or a single path string.
        # A single path is useful for tables that only have one source format.
        if isinstance(file_spec, str):
            if file_spec.lower().endswith(".parquet"):
                parquet_rel, csv_rel = file_spec, None
            else:
                parquet_rel, csv_rel = None, file_spec
        elif isinstance(file_spec, (tuple, list)) and len(file_spec) == 2:
            parquet_rel, csv_rel = file_spec
        else:
            raise ValueError(
                f"Invalid file mapping for table {table_name}: {file_spec!r}. "
                "Use a path string or a (parquet_path, csv_path) pair."
            )

        parquet_path = PROJECT_DIR / parquet_rel if parquet_rel else None
        csv_path = PROJECT_DIR / csv_rel if csv_rel else None

        if parquet_path and parquet_path.exists():
            source = f"read_parquet('{parquet_path.as_posix()}')"
        elif csv_path and csv_path.exists():
            source = f"read_csv_auto('{csv_path.as_posix()}', header = true)"
        else:
            raise FileNotFoundError(
                f"No Parquet or CSV file found for table {table_name}"
            )
        safe_table_name = table_name.replace('"', '""')
        con.execute(
            f'CREATE VIEW "{safe_table_name}" AS SELECT * FROM {source}'
        )
    return con
