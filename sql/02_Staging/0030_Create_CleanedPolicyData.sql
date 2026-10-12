use InsurancePrograms;
GO

/*
----------------------------------------------------------------------------------------------------------------------------------------------
Script Name:
	01_Create_CleanedPolicyData.sql

Purpose:
	Creates the PolicyData table under the 'Cleaned' schema.

----------------------------------------------------------------------------------------------------------------------------------------------
*/


if OBJECT_ID('Cleaned.PolicyData','U') is null
begin
	create table Cleaned.PolicyData
    (
         policy_transaction_id        varchar(100)   not null
        ,policy_id                    varchar(100)   not null
        ,policyholder_id              varchar(100)   not null
        ,insured_name                 varchar(500)   not null
        ,naics_code                   varchar(6)     null
        ,transaction_type             varchar(100)   not null
        ,[program_name]               varchar(200)   not null
        ,policy_type                  varchar(200)   not null
        ,coverage_basis               varchar(100)   not null
        ,[state]                      varchar(2)     not null

        ,effective_date               date           not null
        ,expiration_date              date           not null
        ,retroactive_date             date           null

        ,occurrence_limit             decimal(18,2)  null
        ,aggregate_limit              decimal(18,2)  null
        ,retention_type               varchar(100)   null
        ,deductible_amount            decimal(19,6)  null
        ,sir_amount                   decimal(19,6)  null

        ,core_account_number          varchar(5)     not null
        ,renewal_sequence             int            not null
        ,treaty_year                  int            not null

        ,agency_name                  varchar(300)   not null
        ,[broker_premium_%]           decimal(9,6)   null
        ,broker_premium_$             decimal(19,6)  null

        ,carrier_company_name         varchar(300)   not null
        ,[carrier_premium_%]          decimal(9,6)   null
        ,carrier_premium_$            decimal(19,6)  null

        ,ceded_from_entity            varchar(300)   null
        ,ceding_company_name          varchar(300)   null
        ,[ceding_company_premium_%]   decimal(9,6)   null
        ,ceding_premium_$             decimal(19,6)  null

        ,[state_premium_tax_%]        decimal(9,6)   null
        ,state_premium_tax            decimal(19,6)  null
        ,[mcare_fee_%]                decimal(9,6)   null
        ,mcare_fee                    decimal(19,6)  null
        ,[policy_fee_%]               decimal(9,6)   null
        ,policy_fee                   decimal(19,6)  null
        ,[surplus_lines_tax_%]        decimal(9,6)   null
        ,surplus_lines_tax            decimal(19,6)  null
        ,[stamping_fee_%]             decimal(9,6)   null
        ,stamping_fee                 decimal(19,6)  null

        ,[non_carrier_total_%]        decimal(9,6)   null
        ,[allocation_check_%]         decimal(9,6)   null

        ,total_premium                decimal(19,6)  not null
        ,source_date                  date           not null

        -- Lineage
        ,tpa_name                     varchar(200)   not null
        ,source_file_name             varchar(500)   not null
        ,raw_load_datetime            datetime2(3)   not null
        ,clean_load_datetime          datetime2(3)   not null
        ,batch_id                     int            not null

        constraint UQ_CleanedPolicy_PolicyTransactionID
            unique (policy_transaction_id)
    );
end;