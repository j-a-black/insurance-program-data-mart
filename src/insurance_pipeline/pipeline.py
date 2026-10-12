# -*- coding: utf-8 -*-
"""
File Name: pipeline.py
"""


from datetime import datetime
import logging
import shutil

import pandas as pd

from src.insurance_pipeline.ingestion import (
    read_source_file,
    standardize_column_names,
    calculate_file_hash,
    add_lineage
)

from src.insurance_pipeline.validation import (
    validate_columns
)

from src.insurance_pipeline.tracking import (
    create_batch,
    complete_batch,
    fail_batch,
    create_file_log,
    validate_file_log,
    complete_file_log,
    fail_file_log,
    check_duplicate_file,
    log_duplicate_file
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
        # for file in files:
        
        #     destination = archive_folder / file.name
        #     shutil.move(str(file),str(destination))
        #     logging.info(f"Archived: {file.name}")
        
        
        # Complete batch anduUpdate Ctl.BatchLog
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
        
        # for file in all_files:
            
        #     if file.exists():
        #         destination = error_folder / file.name
        #         shutil.move(str(file), str(destination))
        #         logging.info(f"Moved to error folder: {file.name}")
        
        raise