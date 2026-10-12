# -*- coding: utf-8 -*-
"""Insurance Program Data Mart source ingestion pipeline."""


import os
import logging

from src.insurance_pipeline.configuration import source_config
from src.insurance_pipeline.database import create_database_engine
from src.insurance_pipeline.pipeline import process_source


def main():
    
    #Logging configuration
    log_file = os.getenv("ETL_LOG_FILE", "etl.log")
    
    logging.basicConfig(
        filename=log_file,
        level=logging.INFO,
        format="%(asctime)s | %(levelname)s | %(message)s"
    )
    
    
    
    # Database engine
    engine = create_database_engine()
    
    
    # Start file processing, validation and upload
    # -------------------------------------------------
    for source_name,config in source_config.items():
        process_source(engine, source_name, config)
        
        
if __name__ == "__main__":
    
    main()
    
    
    
    
    
    
    

