USE InsurancePrograms;
GO

/*
----------------------------------------------------------------------------------------------------------------------------------------------
Script Name:
	0060_usp_Load_DimPolicy.sql

Purpose:
	Populates the Policy dimension table using by sourcing Cleaned.PolicyData table. 
----------------------------------------------------------------------------------------------------------------------------------------------
*/

create or alter procedure Curated.usp_LoadDimPolicy
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
	delete from ctl.LoadValidationError
	where BatchID = @batch_id
		and ValidationStage = 'CleanedToCurated'
		and EntityName = 'Policy'


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
            ,'Policy'
            ,null
            ,null
            ,null
            ,null
            ,null
            ,'DP_BATCH_001'
            ,'Batch Validation'
            ,'Error'
            ,'No Cleaned Policy rows were found for the supplied batch_id.'
            ,@validation_datetime
        );
    end;


	-- Validated policy_id is associated with only one core_account_number
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
        ,'Policy'
        ,null
        ,min(cp.source_file_name)
        ,cp.policy_id
        ,'core_account_number'
        ,null
        ,'DP_REL_001'
        ,'Relationship Validation'
        ,'Error'
        ,'policy_id is associated with more than one core_account_number in the batch.'
        ,@validation_datetime
    from Cleaned.PolicyData cp

    where cp.batch_id = @batch_id
    group by cp.batch_id, cp.policy_id
    having count(distinct cp.core_account_number) > 1;


    -- Validated policy_id is associated with only one effective_date
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
        ,'Policy'
        ,null
        ,min(cp.source_file_name)
        ,cp.policy_id
        ,'effective_date'
        ,null
        ,'DP_REL_002'
        ,'Relationship Validation'
        ,'Error'
        ,'policy_id is associated with more than one effective_date in the batch.'
        ,@validation_datetime
    from Cleaned.PolicyData cp

    where cp.batch_id = @batch_id
    group by cp.batch_id, cp.policy_id
    having count(distinct cp.effective_date) > 1;


    -- Validated policy_id is associated with only one expiration_date
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
        ,'Policy'
        ,null
        ,min(cp.source_file_name)
        ,cp.policy_id
        ,'expiration_date'
        ,null
        ,'DP_REL_003'
        ,'Relationship Validation'
        ,'Error'
        ,'policy_id is associated with more than one expiration_date in the batch.'
        ,@validation_datetime
    from Cleaned.PolicyData cp

    where cp.batch_id = @batch_id
    group by cp.batch_id, cp.policy_id
    having count(distinct cp.expiration_date) > 1;


    -- Validated policy_id is associated with only one renewel_sequence
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
        ,'Policy'
        ,null
        ,min(cp.source_file_name)
        ,cp.policy_id
        ,'renewal_sequence'
        ,null
        ,'DP_REL_004'
        ,'Relationship Validation'
        ,'Error'
        ,'policy_id is associated with more than one renewal_sequence in the batch.'
        ,@validation_datetime
    from Cleaned.PolicyData cp

    where cp.batch_id = @batch_id
    group by cp.batch_id, cp.policy_id
    having count(distinct cp.renewal_sequence) > 1;


    -- Validated policy_id is associated with only one treaty_year
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
        ,'Policy'
        ,null
        ,min(cp.source_file_name)
        ,cp.policy_id
        ,'treaty_year'
        ,null
        ,'DP_REL_005'
        ,'Relationship Validation'
        ,'Error'
        ,'policy_id is associated with more than one treaty_year in the batch.'
        ,@validation_datetime
    from Cleaned.PolicyData cp

    where cp.batch_id = @batch_id
    group by cp.batch_id, cp.policy_id
    having count(distinct cp.treaty_year) > 1;


    -- Validated policy_id is associated with only one coverage_basis
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
        ,'Policy'
        ,null
        ,min(cp.source_file_name)
        ,cp.policy_id
        ,'coverage_basis'
        ,null
        ,'DP_REL_006'
        ,'Relationship Validation'
        ,'Error'
        ,'policy_id is associated with more than one coverage_basis in the batch.'
        ,@validation_datetime
    from Cleaned.PolicyData cp

    where cp.batch_id = @batch_id
    group by cp.batch_id, cp.policy_id
    having count(distinct cp.coverage_basis) > 1;


    -- Stops execution of script if validation errors exist; will return rather than throw
	-------------------------------------------------------------------------------------------
    if exists
	(
		select 1
		from Ctl.LoadValidationError
		where BatchID = @batch_id
			and ValidationStage = 'CleanedToCurated'
			and EntityName = 'Policy'
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
				and EntityName = 'Policy'
		group by ValidationCode, ValidationType
        order by ValidationCode;

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
				and EntityName = 'Policy'

        order by RecordIdentifier,ValidationCode;

		return;
	end;


    -- Load DimPolicy
	-------------------------------------------------------------------------------------------
    begin try

        begin transaction;

        --Update existing policies 
        with PolicySource as
        (
            select
                 cp.policy_id
                ,cp.core_account_number
                ,cp.policy_type
                ,cp.coverage_basis
                ,cp.effective_date
                ,cp.expiration_date
                ,cp.retroactive_date
                ,cp.occurrence_limit
                ,cp.aggregate_limit
                ,cp.retention_type
                ,cp.deductible_amount
                ,cp.sir_amount
                ,cp.treaty_year
                ,cp.renewal_sequence

                ,row_number() over
                (partition by cp.policy_id 
                order by cp.source_date desc ,cp.policy_transaction_id desc
                ) RowNum
            from Cleaned.PolicyData cp
            where cp.batch_id = @batch_id
        )

        update dp

        set
             dp.CoreAccountNumber = ps.core_account_number
            ,dp.PolicyType = ps.policy_type
            ,dp.CoverageBasis = ps.coverage_basis
            ,dp.EffectiveDate = ps.effective_date
            ,dp.ExpirationDate = ps.expiration_date
            ,dp.RetroactiveDate = ps.retroactive_date
            ,dp.OccurrenceLimit = ps.occurrence_limit
            ,dp.AggregateLimit = ps.aggregate_limit
            ,dp.RetentionType = ps.retention_type
            ,dp.DeductibleAmount = ps.deductible_amount
            ,dp.SIRAmount = ps.sir_amount
            ,dp.TreatyYear = ps.treaty_year
            ,dp.RenewalSequence = ps.renewal_sequence
        from Curated.DimPolicy dp
        inner join PolicySource ps
            on dp.PolicyID = ps.policy_id

        where ps.RowNum = 1
            and
            (
                dp.CoreAccountNumber <> ps.core_account_number
                or dp.PolicyType <> ps.policy_type
                or dp.CoverageBasis <> ps.coverage_basis
                or dp.EffectiveDate <> ps.effective_date
                or dp.ExpirationDate <> ps.expiration_date
                or isnull(dp.RetroactiveDate, convert(DATE, '99991231')) <> isnull(ps.retroactive_date, CONVERT(DATE, '99991231'))
                or isnull(dp.OccurrenceLimit, -1) <> isnull(ps.occurrence_limit, -1)
                or isnull(dp.AggregateLimit, -1) <> isnull(ps.aggregate_limit, -1)
                or isnull(dp.RetentionType, '') <> isnull(ps.retention_type, '')
                or isnull(dp.DeductibleAmount, -1) <> isnull(ps.deductible_amount, -1)
                or isnull(dp.SIRAmount, -1) <> isnull(ps.sir_amount, -1)
                or dp.TreatyYear <> ps.treaty_year
                or dp.RenewalSequence <> ps.renewal_sequence
          );

        set @rows_updated = @@ROWCOUNT;

        
        -- Insert new policy terms
        with PolicySource as
        (
            select
                 cp.policy_id
                ,cp.core_account_number
                ,cp.policy_type
                ,cp.coverage_basis
                ,cp.effective_date
                ,cp.expiration_date
                ,cp.retroactive_date
                ,cp.occurrence_limit
                ,cp.aggregate_limit
                ,cp.retention_type
                ,cp.deductible_amount
                ,cp.sir_amount
                ,cp.treaty_year
                ,cp.renewal_sequence

                ,row_number() over
                (partition by cp.policy_id
                 order by cp.source_date desc,cp.policy_transaction_id desc
                ) RowNum

            from Cleaned.PolicyData cp

            where cp.batch_id = @batch_id
        )

        insert into Curated.DimPolicy
        (
             PolicyID
            ,CoreAccountNumber
            ,PolicyType
            ,CoverageBasis
            ,EffectiveDate
            ,ExpirationDate
            ,RetroactiveDate
            ,OccurrenceLimit
            ,AggregateLimit
            ,RetentionType
            ,DeductibleAmount
            ,SIRAmount
            ,TreatyYear
            ,RenewalSequence
        )
        select
             ps.policy_id
            ,ps.core_account_number
            ,ps.policy_type
            ,ps.coverage_basis
            ,ps.effective_date
            ,ps.expiration_date
            ,ps.retroactive_date
            ,ps.occurrence_limit
            ,ps.aggregate_limit
            ,ps.retention_type
            ,ps.deductible_amount
            ,ps.sir_amount
            ,ps.treaty_year
            ,ps.renewal_sequence
        from PolicySource ps
        where ps.RowNum = 1
        and not exists
        (
            select 1
            from Curated.DimPolicy dp
            where dp.PolicyID = ps.policy_id
        );

        set @rows_inserted = @@ROWCOUNT;

        commit transaction;
    end try

    begin catch
        if @@TRANCOUNT > 0
            rollback transaction;
        throw;
    end catch;


	-- Return load results
	-------------------------------------------------------------------------------------------
    select
         @batch_id AS BatchID
        ,@rows_updated AS RowsUpdated
        ,@rows_inserted AS RowsInserted;
end;
go