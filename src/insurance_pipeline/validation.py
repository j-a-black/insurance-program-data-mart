# -*- coding: utf-8 -*-
"""
File Name: validation.py
"""


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
        