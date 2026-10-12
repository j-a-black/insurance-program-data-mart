# -*- coding: utf-8 -*-
"""
File Name: tracking.py
"""


from sqlalchemy import text


# Batch
# -------------------------------------------------
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
        
        
# File log
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
        
        
# Duplicates
# -------------------------------------------------
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