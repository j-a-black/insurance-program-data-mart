# -*- coding: utf-8 -*-
"""Insurance Program Data Mart source ingestion pipeline."""

from pathlib import Path
import os
import csv
import pandas as pd
from sqlalchemy import create_engine, text
from datetime import datetime
import logging
import shutil
import hashlib



# Functions
# -------------------------------------------------

def get_file_type(file_path):
    
    extension = file_path.suffix.lower()
    
    if extension == ".xlsx":
        return "excel"
    
    elif extension in [".csv", ".txt"]:
        return "flat_file"
    
    else:
        return "unsupported"
    
    
def detect_delimiter(file_path):
    
    with open(file_path,"r") as file:
        sample = file.read(5000)
        
    sniffer = csv.Sniffer()
    
    delimiter = sniffer.sniff(sample, delimiters=[",","|","\t",";"]).delimiter
    
    return delimiter


def read_source_file(file_path):
    
    file_type = get_file_type(file_path)
    
    if file_type == "excel":
        
        df = pd.read_excel(file_path,dtype="str",keep_default_na=False)
        
    elif file_type == "flat_file":
        
        delimiter = detect_delimiter(file_path)
        
        df = pd.read_csv(file_path,delimiter=delimiter,dtype="str",keep_default_na=False)
        
    else:
        
        raise ValueError(f"Unsupported file type: {file_path.suffix}")
        
    
    return df


def standardize_column_names(df):
    
    df.columns = [
        str(column)
        .strip()
        .lower()
        .replace(" ","_")
        for column in df.columns
        ]
    
    return df


def validate_columns(df, expected_columns, file_name):
    
    errors = []
    
    actual_columns = list(df.columns)
    
    
    # Check for blank/unnamed columns
    # -------------------------------------------------
    blank_columns = [
        column
        for column in actual_columns
        if column is None or str(column).strip() == "" or "unnamed" in str(column).lower()
        ]
    
    if blank_columns:
        errors.append(f"Blank/unnamed columns: {blank_columns}")


    # Check for duplicate columns
    # -------------------------------------------------
    duplicate_columns = df.columns[
        df.columns.duplicated()
        ].tolist()
    
    if duplicate_columns:
        errors.append(
            f"Duplicate columns: {duplicate_columns}"
            )
    
    
    # Check for missing/extra columns
    # -------------------------------------------------
    expected_set = set(expected_columns)
    actual_set = set(actual_columns)
    
    missing_columns = sorted(expected_set - actual_set)
    extra_columns = sorted(actual_set - expected_set)

    if missing_columns:
        errors.append(f"Missing columns: {missing_columns}"
            )
        
    if extra_columns:
        errors.append(f"Unexpected columns: {extra_columns}"
            )
        
    # Check column order
    # -------------------------------------------------
    
    if (
            not missing_columns
            and not extra_columns
            and actual_columns != expected_columns
            ):
        errors.append("Columns in wrong order")
        
    # Raise combined errors
    # -------------------------------------------------
    if errors:
        
        error_details = "\n".join(errors)
        
        raise ValueError(
            f"Column validation failed for {file_name}: \n {error_details}"
            )
        
        
def add_lineage(df,tpa_name,file_name,load_datetime,batch_id):
    
    df["tpa_name"] = tpa_name
    df["source_file_name"] = file_name
    df["raw_load_datetime"] = load_datetime
    df["batch_id"] = batch_id
    
    return df
    
    
def create_batch(engine, source_system, source_path):
    
    sql = text("""
           INSERT INTO Ctl.BatchLog
           (
               SourceSystem
               ,SourcePath
               ,BatchStatus
               ,StartDateTime
               )
           OUTPUT INSERTED.BatchID
           VALUES
           (
               :source_system
               ,:source_path
               ,'STARTED'
               ,GETDATE()
               );
           
           """)
           
    with engine.begin() as connection:
        
        result = connection.execute(
            sql,
            {
                "source_system": source_system,
                "source_path": str(source_path)
                }
            )
        
        batch_id = result.scalar_one()
        
    return batch_id


def complete_batch(engine,batch_id,load_datetime,file_count,source_row_count,loaded_row_count):
    
    sql = text("""
               UPDATE Ctl.BatchLog
               SET
                   BatchStatus = 'Loaded'
                   ,LoadDateTime = :load_datetime
                   ,FileCount = :file_count
                   ,SourceRowCount = :source_row_count
                   ,LoadedRowCount = :loaded_row_count
               WHERE BatchID = :batch_id;
               """)
               
    with engine.begin() as connection:
        
        connection.execute(
            sql,
            {
                "batch_id": batch_id,
                "load_datetime": load_datetime,
                "file_count": file_count,
                "source_row_count": source_row_count,
                "loaded_row_count": loaded_row_count
                }
            )
        
    
def fail_batch(engine,batch_id,error_message):
    
    sql = text("""
           UPDATE Ctl.BatchLog
               SET
                   BatchStatus = 'Failed'
                   ,LoadDateTime = GETDATE()
                   ,Notes = :error_message
           WHERE BatchID = :batch_id;
           """)
           
    with engine.begin() as connection:
        
        connection.execute(
            sql,
            {
                "batch_id": batch_id,
                "error_message": str(error_message)[:5000]
                }
            )
        

def process_source(engine,source_name,config):
    
    # Source folders
    # -------------------------------------------------
    data_folder = config["data_folder"]

    archive_folder = data_folder / "Archive"
    error_folder = data_folder / "Error"

    archive_folder.mkdir(
        parents=True,
        exist_ok=True
    )

    error_folder.mkdir(
        parents=True,
        exist_ok=True
    )
    
    
    # Find source files
    # -------------------------------------------------
    all_files = [
        file
        for file in data_folder.iterdir()
        if file.is_file()
        ]
    
    
    # No files to process procedure
    # -------------------------------------------------
    if not all_files:
        
        logging.info(f"No files found in: {source_name}")
        
        return
    
    
    # Identified supported & unsupported files
    # -------------------------------------------------
    supported_extensions = config["supported_extensions"]
    
    supported_files = [
        file
        for file in all_files
        if file.suffix.lower() in supported_extensions
        ]
    
    unsupported_files = [
        file
        for file in all_files
        if file.suffix.lower() not in supported_extensions
        ]
    
    
    # Create batch ID for Ctl.BatchLog
    # -------------------------------------------------
    batch_id = create_batch(engine, config["source_system"], data_folder)
    
    logging.info(f"BatchID {batch_id} started for source: {source_name}")
    
    
    try:
        # Validate file types
        # -------------------------------------------------
        if unsupported_files:
            
            unsupported_names = [
                file.name
                for file in unsupported_files
                ]
            
            raise ValueError(
                f"Unsupported files found: {unsupported_names}"
                )
            
        
        # Read and validate files sources
        # -------------------------------------------------
        files = supported_files
        dataframes = []
        load_datetime = datetime.now()
        source_file_count = 0
        source_row_count = 0
        file_logs = []
        
        
        for file in files:
            
            file_hash = calculate_file_hash(file)
            
            # if file_was_loaded(engine,file.name):
                
            #     raise ValueError(f"File has already been loaded: {file.name}")
            
            duplicate = check_duplicate_file(engine,config["source_system"],file_hash)
            
            if duplicate:

                notes = (
                     f"Previously loaded in "
                     f"BatchID {duplicate['BatchID']} "
                     f"as {duplicate['SourceFileName']}."
                 )
                 
                log_duplicate_file(engine,batch_id,file,file_hash,notes)
                 
                raise ValueError(
                     f"Duplicate file detected: {file.name}. {notes}"
                 )
            
            file_log_id = create_file_log(engine, batch_id, file, file_hash)
            
            try:
            
                logging.info(f"Reading: {file.name}")
                
                df = read_source_file(file)
                
                df = standardize_column_names(df)
                
                validate_columns(df, config["expected_columns"], file.name)
                
                file_row_count = len(df)
                
                validate_file_log(engine, file_log_id, file_row_count)
                
                df = add_lineage(df, config["tpa_name"], file.name, load_datetime, batch_id)
                
                source_file_count += 1
                source_row_count += len(df)
                
                dataframes.append(df)
                
                file_logs.append(
                    {
                        "file": file,
                        "file_log_id": file_log_id,
                        "row_count": file_row_count
                        }
                    )
            except Exception as error:
                
                fail_file_log(engine, file_log_id, error)
                
                raise
            
            
        # Combine source files
        # -------------------------------------------------
        combined_df = pd.concat(dataframes,ignore_index=True)
        combined_row_count = len(combined_df)
        
        
        # Validate row count
        # -------------------------------------------------
        if source_row_count != combined_row_count:
            raise ValueError(
                "Row count validation failed."
                f"Source rows: {source_row_count:,},"
                f"Combined rows: {combined_row_count:,}"
                )
        
        logging.info(f"Number of files processed: {source_file_count}")
        logging.info(f"Number of rows processed: {combined_row_count:,}")
        
        # Load to SQL Server
        # -------------------------------------------------
        with engine.begin() as connection:
        
            combined_df.to_sql(
                name=config["table_name"],
                con=connection,
                schema=config["schema_name"],
                if_exists="append",
                index=False
                )
        
        
        # Update FileLog
        # -------------------------------------------------
        for file_record in file_logs:
            
            complete_file_log(
                engine, file_record["file_log_id"], file_record["row_count"], load_datetime
                )
        
        
        # Archive files
        # -------------------------------------------------
        complete_batch(
            engine,
            batch_id = batch_id,
            load_datetime = load_datetime,
            file_count = len(files),
            source_row_count = source_row_count,
            loaded_row_count = combined_row_count
            )
        
        
    except Exception as error:
        
        logging.exception(f"BatchID {batch_id} failed")
        
        fail_batch(engine,batch_id,error)
        
        raise
        
        
def create_file_log(engine,batch_id,file_path,file_hash):
    
    sql = text("""
               INSERT INTO Ctl.FileLog (
                   BatchID,
                   SourceFileName,
                   FileExtension,
                   FileHash,
                   FileStatus,
                   StartDateTime
                   )
               OUTPUT INSERTED.FileLogID
               VALUES
               (
                   :batch_id,
                   :source_file_name,
                   :file_extension,
                   :file_hash,
                   'STARTED',
                   GETDATE()
                   );
               """)
    
    with engine.begin() as connection:
        
        result = connection.execute(
                sql,
                {
                    "batch_id": batch_id,
                    "source_file_name": file_path.name,
                    "file_extension": file_path.suffix.lower(),
                    "file_hash": file_hash
                    }
            )
        
        file_log_id = result.scalar_one()
        
        return file_log_id
    
    
def complete_file_log(engine,file_log_id,file_row_count,load_datetime):
    
    sql = text("""
               UPDATE Ctl.FileLog
                   SET
                       FileStatus = 'Loaded',
                       FileRowCount = :file_row_count,
                       LoadDateTime = :load_datetime
               WHERE FileLogID = :file_log_id;
               """)
    
    with engine.begin() as connection:
        
        connection.execute(
            sql,
            {
                "file_log_id": file_log_id,
                "file_row_count": file_row_count,
                "load_datetime": load_datetime
                }
            )
        

def validate_file_log(engine,file_log_id,file_row_count):
    
    sql = text("""
               UPDATE Ctl.FileLog
               SET
                   FileStatus = 'Validated',
                   FileRowCount = :file_row_count
               WHERE FileLogID = :file_log_id
               """)
               
    with engine.begin() as connection:
        
        connection.execute(
            sql,
            {
                "file_log_id": file_log_id,
                "file_row_count": file_row_count
                }
            )

def fail_file_log(engine,file_log_id,error_message):

    sql = text("""
        UPDATE Ctl.FileLog
        SET
            FileStatus = 'Failed',
            LoadDateTime = GETDATE(),
            Notes = :error_message
        WHERE FileLogID = :file_log_id;
    """)

    with engine.begin() as connection:

        connection.execute(
            sql,
            {
                "file_log_id": file_log_id,
                "error_message": str(error_message)[:5000]
            }
        )
   
        
def check_duplicate_file(engine,source_system,file_hash):

    sql = text("""
        SELECT TOP 1
            fl.FileLogID,
            fl.BatchID,
            fl.SourceFileName,
            fl.LoadDateTime
        FROM Ctl.FileLog AS fl
        INNER JOIN Ctl.BatchLog AS bl
            ON fl.BatchID = bl.BatchID
        WHERE fl.FileHash = :file_hash
          AND fl.FileStatus = 'Loaded'
          AND bl.SourceSystem = :source_system
        ORDER BY fl.LoadDateTime DESC;
    """)

    with engine.connect() as connection:

        result = connection.execute(
            sql,
            {
                "file_hash": file_hash,
                "source_system":
                    source_system
            }
        )

        duplicate = (
            result.mappings().first()
        )


    return duplicate
        

def calculate_file_hash(file_path):
    
    sha256 = hashlib.sha256()
    
    with open(file_path,"rb") as file:
        
        for chunk in iter(lambda: file.read(8192),b""):
            sha256.update(chunk)
            
        
        return sha256.hexdigest()
    
    
def file_hash_was_loaded(engine,file_hash):
    
    sql = text("""
               SELECT COUNT(*)
               FROM Ctl.FileLog
               WHERE FileHash = :file_hash
                   AND FileStatus = 'Loaded';
               """)
               
    with engine.begin() as connection:
        
        result = connection.execute(
            sql,
            {
                "file_hash": file_hash
                }
            )
        
        count = result.scalar_one()
        
        
    return count > 0


def log_duplicate_file(engine,batch_id,file_path,file_hash,notes):

    sql = text("""
        INSERT INTO Ctl.FileLog
        (
            BatchID,
            SourceFileName,
            FileExtension,
            FileHash,
            FileStatus,
            StartDateTime,
            LoadDateTime,
            Notes
        )
        VALUES
        (
            :batch_id,
            :source_file_name,
            :file_extension,
            :file_hash,
            'Duplicate',
            GETDATE(),
            GETDATE(),
            :notes
        );
    """)

    with engine.begin() as connection:

        connection.execute(
            sql,
            {
                "batch_id": batch_id,
                "source_file_name": file_path.name,
                "file_extension": file_path.suffix.lower(),
                "file_hash": file_hash,
                "notes": notes
            }
        )
    
        
# ===============================================================================================================
# MAIN
# ===============================================================================================================


# Configuration
# -------------------------------------------------
BASE_DATA_PATH = Path(os.getenv("INSURANCE_DATA_PATH", "data"))

source_config = {
    
        "bda_claims": {
                "data_folder": BASE_DATA_PATH / "claims_data",
                "source_system": "BDAClaims",
                "tpa_name": "Beacon Dynamic Agency",
                "schema_name": "Raw",
                "table_name": "ClaimsData",
                "supported_extensions": [".csv",".txt",".xlsx"],
                "expected_columns": [
                    "claim_id",
                    "policy_id",
                    "policyholder_id",
                    "program_name",
                    "carrier_company_name",
                    "loss_date",
                    "reported_date",
                    "record_date",
                    "reporting_month",
                    "claim_status",
                    "state",
                    "indemnity_reserve",
                    "indemnity_paid",
                    "alae_reserve",
                    "alae_paid",
                    "salvage_recovery",
                    "subrogation_recovery",
                    "deductible_recovery",
                    "denial_reason",
                    "source_date"
                    ]
            },
        
        "bda_policy": {
                "data_folder": BASE_DATA_PATH / "policy_data",
                "source_system": "BDAPolicy",
                "tpa_name": "Beacon Dynamic Agency",
                "schema_name": "Raw",
                "table_name": "PolicyData",
                "supported_extensions": [".csv",".txt",".xlsx"],
                "expected_columns": [
                    "policy_transaction_id",
                    "policy_id",
                    "policyholder_id",
                    "insured_name",
                    "naics_code",
                    "transaction_type",
                    "program_name",
                    "policy_type",
                    "coverage_basis",
                    "state",
                    "effective_date",
                    "expiration_date",
                    "retroactive_date",
                    "occurrence_limit",
                    "aggregate_limit",
                    "retention_type",
                    "deductible_amount",
                    "sir_amount",
                    "core_account_number",
                    "renewal_sequence",
                    "treaty_year",
                    "agency_name",
                    "broker_premium_%",
                    "broker_premium_$",
                    "carrier_company_name",
                    "carrier_premium_%",
                    "carrier_premium_$",
                    "ceded_from_entity",
                    "ceding_company_name",
                    "ceding_company_premium_%",
                    "ceding_premium_$",
                    "state_premium_tax_%",
                    "state_premium_tax",
                    "mcare_fee_%",
                    "mcare_fee",
                    "policy_fee_%",
                    "policy_fee",
                    "surplus_lines_tax_%",
                    "surplus_lines_tax",
                    "stamping_fee_%",
                    "stamping_fee",
                    "non_carrier_total_%",
                    "allocation_check_%",
                    "total_premium",
                    "source_date"
                    ]
            }
    }


# config = source_config["bda_policy"]
log_file = os.getenv("ETL_LOG_FILE", "etl.log")
logging.basicConfig(
    filename=log_file,
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s"
)


# Create engine to connect to SQL Server
# -------------------------------------------------
server = os.getenv("SQL_SERVER")
database = os.getenv("SQL_DATABASE", "InsurancePrograms")
driver = os.getenv("SQL_DRIVER", "ODBC Driver 17 for SQL Server")

if not server:
    raise EnvironmentError(
        "SQL_SERVER environment variable is required before running the ETL."
    )

connection_str = (
    f"mssql+pyodbc://@{server}/{database}"
    f"?driver={driver.replace(' ', '+')}"
    f"&trusted_connection=yes"
)

engine = create_engine(connection_str,fast_executemany=True)


# Start file processing, validation and upload
# -------------------------------------------------
for source_name,config in source_config.items():
    process_source(engine, source_name, config)
    
    
    
    
    
    
    

