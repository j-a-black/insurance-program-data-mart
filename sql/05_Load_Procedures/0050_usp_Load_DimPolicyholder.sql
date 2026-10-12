USE InsurancePrograms;
GO

/*
----------------------------------------------------------------------------------------------------------------------------------------------
Script Name:
	0050_usp_Load_DimPolicyholder.sql

Purpose:
	Populates the Policyholder dimension table using by sourcing Cleaned.PolicyData table. 
----------------------------------------------------------------------------------------------------------------------------------------------
*/


create or alter procedure Curated.usp_LoadDimPolicyholder
	@batch_id int
as
begin
	set nocount ON;
	set xact_abort ON;

	declare @validation_datetime datetime2(3) = getdate();
	declare @rows_updated int = 0;
	declare @rows_inserted int = 0;


	-- Clear prior validation results
	-------------------------------------------------------------------------------------------
	delete from Ctl.LoadValidationError
	where BatchID = @batch_id
		and ValidationStage = 'CleanedToCurated'
		and EntityName = 'Policyholder'

	
	-- Validate batch exists in Cleaned.PolicyData
	-------------------------------------------------------------------------------------------
	if not exists
	(
		select 1
		from Cleaned.PolicyData
		where batch_id = @batch_id
	)
	begin
	    insert into Ctl.LoadValidationError
		(
			BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
			,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
			,ValidationType, Severity, ErrorMessage, ValidationDatetime
		)
        values
        (
             @batch_id
            ,'CleanedToCurated'
            ,'Policyholder'
            ,null
            ,null
            ,null
            ,null
            ,null
            ,'PH_BATCH_001'
            ,'Batch Validation'
            ,'Error'
            ,'No Cleaned Policy rows were found for the supplied batch_id.'
            ,@validation_datetime
        );
	end;


	-- Validated policyholder_id is associated with only one insured_name
	-------------------------------------------------------------------------------------------
	insert into Ctl.LoadValidationError
		(
			 BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
			,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
			,ValidationType, Severity, ErrorMessage, ValidationDatetime
		)
	select
         cp.batch_id
        ,'CleanedToCurated'
        ,'Policyholder'
        ,null
        ,min(cp.source_file_name)
        ,cp.policyholder_id
        ,'insured_name'
        ,null
        ,'PH_REL_001'
        ,'Relationship Validation'
        ,'Error'
        ,'policyholder_id is associated with more than one insured_name in the batch.'
        ,@validation_datetime
    from Cleaned.PolicyData cp

	where cp.batch_id = @batch_id
	group by cp.batch_id, cp.policyholder_id
	having count(distinct cp.insured_name) > 1;


	-- Validated policyholder_id is associated with only one naics_code
	-------------------------------------------------------------------------------------------
	insert into Ctl.LoadValidationError
	(
		 BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
		,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
		,ValidationType, Severity, ErrorMessage, ValidationDatetime
	)
    select
         cp.batch_id
        ,'CleanedToCurated'
        ,'Policyholder'
        ,null
        ,MIN(cp.source_file_name)
        ,cp.policyholder_id
        ,'naics_code'
        ,null
        ,'PH_REL_002'
        ,'Relationship Validation'
        ,'Error'
        ,'policyholder_id is associated with more than one NAICS code in the batch.'
        ,@validation_datetime
    from Cleaned.PolicyData AS cp

    where cp.batch_id = @batch_id
	group by cp.batch_id, cp.policyholder_id
	having count(distinct cp.naics_code) > 1;


	-- Stops execution of script if validation errors exist; will return rather than throw
	-------------------------------------------------------------------------------------------
	if exists
	(
		select 1
		from Ctl.LoadValidationError
		where BatchID = @batch_id
			and ValidationStage = 'CleanedToCurated'
			and EntityName = 'Policyholder'
			and Severity = 'Error'
	)
	begin
		select
			ValidationCode
			,ValidationType
			,count(*) as ValidationCount
		from Ctl.LoadValidationError
		where BatchID = @batch_id
				and ValidationStage = 'CleanedToCurated'
				and EntityName = 'Policyholder'
		group by ValidationCode, ValidationType
		order by ValidationCode

		select
			ValidationErrorID
			,BatchID
			,RecordIdentifier
			,ColumnName
			,ValidationCode
			,ValidationType
			,Severity
			,ErrorMessage
			,ValidationDatetime
		from Ctl.LoadValidationError
		where BatchID = @batch_id
				and ValidationStage = 'CleanedToCurated'
				and EntityName = 'Policyholder'

		return;
	end;


	-- Load DimPolicyholder
	-------------------------------------------------------------------------------------------
	begin try
		begin transaction;

		-- Update existing policyholders
		with PolicyholderSource as
		(
			select
				cp.policyholder_id
				,cp.insured_name
				,cp.naics_code
				,row_number() over 
				(
					partition by cp.policyholder_id 
					order by cp.source_date desc, cp.policy_transaction_id desc
				) as RowNum
			from Cleaned.PolicyData as cp
			where cp.batch_id = @batch_id
		)
		update dph
			set
				dph.PolicyholderName = ps.insured_name
				,dph.NAICSCode = ps.naics_code
		from Curated.DimPolicyholder dph
		inner join PolicyholderSource ps
			on dph.PolicyholderID = ps.policyholder_id
		where ps.RowNum = 1
			and
			(
				dph.PolicyholderID <> ps.policyholder_id
				or isnull(dph.NAICSCode,'') <> ps.naics_code
			)

		set @rows_updated = @@ROWCOUNT;

		-- Insert new policyholders
		with PolicyholderSource as
		(
			select
				cp.policyholder_id
				,cp.insured_name
				,cp.naics_code
				,row_number() over 
				(
					partition by cp.policyholder_id 
					order by cp.source_date desc, cp.policy_transaction_id desc
				) as RowNum
			from Cleaned.PolicyData as cp
			where cp.batch_id = @batch_id
		)
		insert into Curated.DimPolicyholder
        (
             PolicyholderID
            ,PolicyholderName
            ,NAICSCode
        )
        select
             ps.policyholder_id
            ,ps.insured_name
            ,ps.naics_code

        FROM PolicyholderSource ps

        WHERE ps.RowNum = 1

          and not exists
          (
              select 1

              from Curated.DimPolicyholder dph

              where dph.PolicyholderID = ps.policyholder_id
          );


        set @rows_inserted = @@ROWCOUNT;


        commit transaction;
	end try

		begin catch
			if @@TRANCOUNT > 0
				rollback transaction;

			throw;

	end catch

	-- Return load results
	-------------------------------------------------------------------------------------------
	select
		@batch_id AS BatchID
		,@rows_updated AS RowsUpdated
		,@rows_inserted AS RowsInserted;
end;
go