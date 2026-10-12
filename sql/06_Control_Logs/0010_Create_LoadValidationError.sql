USE InsurancePrograms;
GO

/*
----------------------------------------------------------------------------------------------------------------------------------------------
Script Name:
	0010_Create_LoadValidationError.sql

Purpose:
	Loads data from the 'Raw' schema to the 'Clean' schema.
----------------------------------------------------------------------------------------------------------------------------------------------
*/


-- Create new table if one does not exist.
if object_id('Ctl.LoadValidationError','U') is null
begin
create table Ctl.LoadValidationError
(
     ValidationErrorID      bigint identity(1,1) not null
    ,BatchID                int                  not null
    ,ValidationStage        varchar(50)          not null
    ,EntityName             varchar(50)          not null

    ,RawRowID               bigint              null

    ,SourceFileName         varchar(500)         null
    ,RecordIdentifier       varchar(200)         null
    ,ColumnName             varchar(200)         null
    ,InvalidValue           varchar(1000)        null

    ,ValidationCode         varchar(50)          not null
    ,ValidationType         varchar(100)         not null
    ,Severity               varchar(20)          not null
    ,ErrorMessage           varchar(1000)        not null

    ,ValidationDatetime     datetime2(3)         not null

    constraint PK_LoadValidationError
        primary key (ValidationErrorID)
);
end;