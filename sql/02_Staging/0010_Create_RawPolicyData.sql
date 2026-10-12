use InsurancePrograms;
GO

/*
----------------------------------------------------------------------------------------------------------------------------------------------
Script Name:
	01_Create_RawPolicyData.sql

Purpose:
	Creates PolicyData table under the 'Raw' schema for raw data ingestion.

----------------------------------------------------------------------------------------------------------------------------------------------
*/


-- Create new table if one does not exist.
if OBJECT_ID('Raw.PolicyData','U') is null
begin
	create table [Raw].PolicyData
    (
         RawRowID                      bigint identity(1,1) not null
        ,policy_transaction_id        varchar(100)  null
        ,policy_id                    varchar(100)  null
        ,policyholder_id              varchar(100)  null
        ,insured_name                 varchar(500)  null
        ,naics_code                   varchar(50)   null
        ,transaction_type             varchar(100)  null
        ,[program_name]               varchar(200)  null
        ,policy_type                  varchar(200)  null
        ,coverage_basis               varchar(100)  null
        ,[state]                      varchar(50)   null

        ,effective_date               varchar(100)  null
        ,expiration_date              varchar(100)  null
        ,retroactive_date             varchar(100)  null

        ,occurrence_limit             varchar(100)  null
        ,aggregate_limit              varchar(100)  null
        ,retention_type               varchar(100)  null
        ,deductible_amount            varchar(100)  null
        ,sir_amount                   varchar(100)  null

        ,core_account_number          varchar(100)  null
        ,renewal_sequence             varchar(100)  null
        ,treaty_year                  varchar(100)  null

        ,agency_name                  varchar(300)  null
        ,[broker_premium_%]           varchar(100)  null
        ,broker_premium_$             varchar(100)  null

        ,carrier_company_name         varchar(300)  null
        ,[carrier_premium_%]          varchar(100)  null
        ,carrier_premium_$            varchar(100)  null

        ,ceded_from_entity            varchar(300)  null
        ,ceding_company_name          varchar(300)  null
        ,[ceding_company_premium_%]   varchar(100)  null
        ,ceding_premium_$             varchar(100)  null

        ,[state_premium_tax_%]        varchar(100)  null
        ,state_premium_tax            varchar(100)  null
        ,[mcare_fee_%]                varchar(100)  null
        ,mcare_fee                    varchar(100)  null
        ,[policy_fee_%]               varchar(100)  null
        ,policy_fee                   varchar(100)  null
        ,[surplus_lines_tax_%]        varchar(100)  null
        ,surplus_lines_tax            varchar(100)  null
        ,[stamping_fee_%]             varchar(100)  null
        ,stamping_fee                 varchar(100)  null

        ,[non_carrier_total_%]        varchar(100)  null
        ,[allocation_check_%]         varchar(100)  null
        ,total_premium                varchar(100)  null
        ,source_date                  varchar(100)  null

        -- Lineage
        ,tpa_name                     varchar(200)  not null
        ,source_file_name             varchar(500)  not null
        ,raw_load_datetime            datetime2(3)  not null
        ,batch_id                     int           not null
    );
end;