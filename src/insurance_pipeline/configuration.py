# -*- coding: utf-8 -*-
"""
File Name: configuration.py

"""

import os
from pathlib import Path
from dotenv import load_dotenv


load_dotenv()


# Database configuration
# ----------------------------------------------------------------------------------
server = os.getenv("SQL_SERVER")
database = os.getenv("SQL_DATABASE", "InsurancePrograms")
driver = os.getenv("SQL_DRIVER", "ODBC Driver 17 for SQL Server")


# Paths
# ----------------------------------------------------------------------------------
BASE_DATA_PATH = Path(os.getenv("INSURANCE_DATA_PATH", "data"))


# Configuration
# ----------------------------------------------------------------------------------
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



