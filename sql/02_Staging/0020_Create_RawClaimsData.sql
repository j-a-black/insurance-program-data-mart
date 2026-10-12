use InsurancePrograms;
GO

/*
----------------------------------------------------------------------------------------------------------------------------------------------
Script Name:
	0020_Create_RawClaimsData.sql

Purpose:
	Creates ClaimsData table under the 'Raw' schema for raw data ingestion.

----------------------------------------------------------------------------------------------------------------------------------------------
*/


-- Create new table if one does not exist.
if OBJECT_ID('Raw.ClaimsData','U') is null
begin
    create table [Raw].ClaimsData
    (
        RawRowID                      bigint identity(1,1) not null
        ,claim_id                     varchar(100)  null
        ,policy_id                    varchar(100)  null
        ,policyholder_id              varchar(100)  null
        ,[program_name]               varchar(200)  null
        ,carrier_company_name         varchar(300)  null

        ,loss_date                    varchar(100)  null
        ,reported_date                varchar(100)  null
        ,record_date                  varchar(100)  null
        ,reporting_month              varchar(100)  null

        ,claim_status                 varchar(100)  null
        ,[state]                      varchar(50)   null

        ,indemnity_reserve            varchar(100)  null
        ,indemnity_paid               varchar(100)  null
        ,alae_reserve                 varchar(100)  null
        ,alae_paid                    varchar(100)  null
        ,salvage_recovery             varchar(100)  null
        ,subrogation_recovery         varchar(100)  null
        ,deductible_recovery          varchar(100)  null

        ,denial_reason                varchar(500)  null
        ,source_date                  varchar(100)  null

        -- Lineage
        ,tpa_name                     varchar(200)  not null
        ,source_file_name             varchar(500)  not null
        ,raw_load_datetime            datetime2(3)  not null
        ,batch_id                     int           not null
    );
end;