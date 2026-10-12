# -*- coding: utf-8 -*-
"""
File name: database.py
"""

from sqlalchemy import create_engine
from src.insurance_pipeline.configuration import (
        server,
        database,
        driver
    )


def create_database_engine():
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
    
    return engine