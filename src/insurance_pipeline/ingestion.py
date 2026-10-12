# -*- coding: utf-8 -*-
"""
File Name: ingestion.py
"""


import csv
import hashlib

import pandas as pd


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


def add_lineage(df,tpa_name,file_name,load_datetime,batch_id):
    
    df["tpa_name"] = tpa_name
    df["source_file_name"] = file_name
    df["raw_load_datetime"] = load_datetime
    df["batch_id"] = batch_id
    
    return df

        
def calculate_file_hash(file_path):
    
    sha256 = hashlib.sha256()
    
    with open(file_path,"rb") as file:
        
        for chunk in iter(lambda: file.read(8192),b""):
            sha256.update(chunk)
            
        
        return sha256.hexdigest()