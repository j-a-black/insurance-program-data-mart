use InsurancePrograms;
GO

/*
----------------------------------------------------------------------------------------------------------------------------------------------
Script Name:
	04_Create_CleanedClaimsData.sql

Purpose:
	Creates the ClaimsData table under the 'Cleaned' schema.

----------------------------------------------------------------------------------------------------------------------------------------------
*/


if OBJECT_ID('Cleaned.ClaimsData','U') is null
begin
	create table Cleaned.ClaimsData
    (
         claim_id                     varchar(100)   not null
        ,policy_id                    varchar(100)   not null
        ,policyholder_id              varchar(100)   not null
        ,[program_name]               varchar(200)   not null
        ,carrier_company_name         varchar(300)   not null

        ,loss_date                    date           not null
        ,reported_date                date           not null
        ,record_date                  date           not null
        ,reporting_month              varchar(7)     not null

        ,claim_status                 varchar(50)    not null
        ,[state]                      varchar(2)     not null

        ,indemnity_reserve            decimal(19,6)  null
        ,indemnity_paid               decimal(19,6)  null
        ,alae_reserve                 decimal(19,6)  null
        ,alae_paid                    decimal(19,6)  null
        ,salvage_recovery             decimal(19,6)  null
        ,subrogation_recovery         decimal(19,6)  null
        ,deductible_recovery          decimal(19,6)  null

        ,denial_reason                varchar(500)   null
        ,source_date                  date           not null

        -- Lineage
        ,tpa_name                     varchar(200)   not null
        ,source_file_name             varchar(500)   not null
        ,raw_load_datetime            datetime2(3)   not null
        ,clean_load_datetime          datetime2(3)   not null
        ,batch_id                     int            not null
    );
end;