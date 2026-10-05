USE InsurancePrograms;
GO

/*
----------------------------------------------------------------------------------------------------------------------------------------------
Script Name:
	0030_usp_Load_PolicyBatch.sql

Purpose:
	Validates then loads data from the 'Raw' schema to the 'Clean' schema.
----------------------------------------------------------------------------------------------------------------------------------------------
*/


create or alter procedure Cleaned.usp_LoadPolicyBatch
	@batch_id int
as
begin
	set nocount ON;
	set xact_abort ON;

	--declare @batch_id int = 16;

	declare @validation_datetime datetime2(3) = getdate();
	declare @clean_load_datetime datetime2(3) = getdate();

	-- Clear previous validation results for this batch
	-------------------------------------------------------------------------------------------------------------------------
	delete from Ctl.LoadValidationError
	where BatchID = @batch_id
		and ValidationStage = 'RawToCleaned'
		and EntityName = 'Policy';


	-- Validate raw batch exists
    -------------------------------------------------------------------------------------------------------------------------
	if not exists
	(
		select 1
		from [Raw].PolicyData
		where batch_id = @batch_id
	)
	insert into Ctl.LoadValidationError
	(
		BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
		,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
		,ValidationType, Severity, ErrorMessage, ValidationDatetime
	)
	values
	(
		@batch_id
		,'RawToCleaned'
		,'Policy'
		,null
		,null
		,null
		,null
		,null
		,'POL_BATCH_001'
		,'Batch Validation'
		,'Error'
		,'No Raw Policy rows were found for the supplied batch_id.'
		,@validation_datetime
	)


	-- Validate required values; should not be NULL
    -------------------------------------------------------------------------------------------------------------------------
	insert into Ctl.LoadValidationError
	(
		BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
		,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
		,ValidationType, Severity, ErrorMessage, ValidationDatetime
	)
	select
		p.batch_id
		,'RawToCleaned'
        ,'Policy'
        ,p.RawRowID
        ,p.source_file_name
        ,nullif(trim(p.policy_transaction_id), '')
        ,v.column_name
		,v.column_value 
		,'POL_REQ_001'
        ,'Required Value'
        ,'Error'
        ,concat(v.column_name, ' is required.')
        ,@validation_datetime
	from [Raw].PolicyData p

	cross apply
	(
		values
			('policy_transaction_id', p.policy_transaction_id)
            ,('policy_id',             p.policy_id)
            ,('policyholder_id',       p.policyholder_id)
            ,('insured_name',          p.insured_name)
            ,('transaction_type',      p.transaction_type)
            ,('program_name',          p.[program_name])
            ,('policy_type',           p.policy_type)
            ,('coverage_basis',        p.coverage_basis)
            ,('state',                 p.[state])
            ,('effective_date',        p.effective_date)
            ,('expiration_date',       p.expiration_date)
            ,('core_account_number',   p.core_account_number)
            ,('renewal_sequence',      p.renewal_sequence)
            ,('treaty_year',           p.treaty_year)
            ,('agency_name',           p.agency_name)
            ,('carrier_company_name',  p.carrier_company_name)
            ,('total_premium',         p.total_premium)
            ,('source_date',           p.source_date)
    ) v(column_name, column_value)

	where p.batch_id = @batch_id
		and nullif(trim(v.column_value),'') is null


	-- Validate date conversions: expected format should be yyyy-mm-dd
    -------------------------------------------------------------------------------------------------------------------------
	insert into Ctl.LoadValidationError
    (
         BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
        ,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
        ,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         p.batch_id
        ,'RawToCleaned'
        ,'Policy'
        ,p.RawRowID
        ,p.source_file_name
        ,nullif(trim(p.policy_transaction_id), '')
        ,v.column_name
        ,v.column_value
        ,'POL_DATE_001'
        ,'Data Type Conversion'
        ,'Error'
        ,concat(v.column_name, ' could not be converted to DATE using yyyy-mm-dd.')
        ,@validation_datetime
    from [Raw].PolicyData p

	cross apply
	(
		values
			('effective_date',   p.effective_date)
            ,('expiration_date',  p.expiration_date)
            ,('retroactive_date', p.retroactive_date)
            ,('source_date',      p.source_date)
	) v(column_name,column_value)

	where p.batch_id = @batch_id
		and nullif(trim(v.column_value),'') is not null
		and try_convert(date,v.column_value,23) is null


	-- Validate whole-number conversion for renewal_sequence and treaty_year
    -------------------------------------------------------------------------------------------------------------------------
	insert into Ctl.LoadValidationError
    (
         BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
        ,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
        ,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         p.batch_id
        ,'RawToCleaned'
        ,'Policy'
        ,p.RawRowID
        ,p.source_file_name
        ,nullif(trim(p.policy_transaction_id), '')
        ,v.column_name
        ,v.column_value
        ,'POL_NUM_001'
        ,'Data Type Conversion'
        ,'Error'
        ,concat(v.column_name, ' could not be converted to the expected integer type.')
        ,@validation_datetime
    from [Raw].PolicyData p

    cross apply
    (
        values
             ('renewal_sequence', p.renewal_sequence, 'int')
            ,('treaty_year',      p.treaty_year,      'int')
    ) v(column_name, column_value, expected_type)

    where p.batch_id = @batch_id
        and nullif(trim(v.column_value),'') is not null
        and v.expected_type = 'int' 
        and try_convert(int,trim(v.column_value)) is null
           
           
    -- Validate monetary conversions: expected format should be decimal(19,6)
    -------------------------------------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
         BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
        ,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
        ,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    SELECT
         p.batch_id
        ,'RawToCleaned'
        ,'Policy'
        ,p.RawRowID
        ,p.source_file_name
        ,nullif(trim(p.policy_transaction_id), '')
        ,v.column_name
        ,v.column_value
        ,'POL_AMT_001'
        ,'Data Type Conversion'
        ,'Error'
        ,concat(v.column_name, ' could not be converted to decimal(19,6).')
        ,@validation_datetime
    from [Raw].PolicyData p

    cross apply
    (
        values
             ('occurrence_limit',    p.occurrence_limit)
            ,('aggregate_limit',     p.aggregate_limit)
            ,('deductible_amount',   p.deductible_amount)
            ,('sir_amount',          p.sir_amount)
            ,('broker_premium_$',    p.broker_premium_$)
            ,('carrier_premium_$',   p.carrier_premium_$)
            ,('ceding_premium_$',    p.ceding_premium_$)
            ,('state_premium_tax',   p.state_premium_tax)
            ,('mcare_fee',           p.mcare_fee)
            ,('policy_fee',          p.policy_fee)
            ,('surplus_lines_tax',   p.surplus_lines_tax)
            ,('stamping_fee',        p.stamping_fee)
            ,('total_premium',       p.total_premium)
    ) v(column_name, column_value)

    where p.batch_id = @batch_id
        and nullif(trim(v.column_value),'') is not null
        and try_convert(decimal(19,6),nullif(trim(v.column_value),'')) is null


    -- Validate percentage conversions: expected format should be decimal(9,6)
    -------------------------------------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
         BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
        ,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
        ,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         p.batch_id
        ,'RawToCleaned'
        ,'Policy'
        ,p.RawRowID
        ,p.source_file_name
        ,nullif(trim(p.policy_transaction_id), '')
        ,v.column_name
        ,v.column_value
        ,'POL_PCT_001'
        ,'Data Type Conversion'
        ,'Error'
        ,concat(v.column_name, ' could not be converted to decimal(9,6).')
        ,@validation_datetime
    from [Raw].PolicyData p
    
    cross apply
    (
        values
             ('broker_premium_%',         p.[broker_premium_%])
            ,('carrier_premium_%',        p.[carrier_premium_%])
            ,('ceding_company_premium_%', p.[ceding_company_premium_%])
            ,('state_premium_tax_%',      p.[state_premium_tax_%])
            ,('mcare_fee_%',              p.[mcare_fee_%])
            ,('policy_fee_%',             p.[policy_fee_%])
            ,('surplus_lines_tax_%',      p.[surplus_lines_tax_%])
            ,('stamping_fee_%',           p.[stamping_fee_%])
            ,('non_carrier_total_%',      p.[non_carrier_total_%])
            ,('allocation_check_%',       p.[allocation_check_%])
    ) v(column_name, column_value)

    where p.batch_id = @batch_id
        and nullif(trim(v.column_value),'') is not null
        and try_convert(decimal(9,6),nullif(trim(v.column_value),'')) is null;


    -- Validate NAICS Code format
    -------------------------------------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
         BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
        ,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
        ,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         p.batch_id
        ,'RawToCleaned'
        ,'Policy'
        ,p.RawRowID
        ,p.source_file_name
        ,nullif(trim(p.policy_transaction_id), '')
        ,'naics_code'
        ,p.naics_code
        ,'POL_NAICS_001'
        ,'Business Rule'
        ,'Error'
        ,'naics_code must contain between 2 and 6 numeric digits when populated.'
        ,@validation_datetime
    from [Raw].PolicyData p
    where p.batch_id = @batch_id
      and nullif(trim(p.naics_code), '') is not null
      and
      (
            len(trim(p.naics_code)) not between 2 and 6
            or trim(p.naics_code) like '%[^0-9]%'
      );


    -- Validate state format and length is (2) characters
    -------------------------------------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
         BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
        ,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
        ,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         p.batch_id
        ,'RawToCleaned'
        ,'Policy'
        ,p.RawRowID
        ,p.source_file_name
        ,nullif(trim(p.policy_transaction_id), '')
        ,'state'
        ,p.[state]
        ,'POL_STATE_001'
        ,'Business Rule'
        ,'Error'
        ,'state must contain a two-character alphabetic state code.'
        ,@validation_datetime
    from Raw.PolicyData p

    where p.batch_id = @batch_id
        and nullif(trim(p.[state]),'') is not null
        and
        (
            len(trim(p.[state])) <> 2
            or upper(trim(p.[state])) like '%[^A-Z]%'
        );


    -- Validate policy_id format: HS-NY-26-40192-00
    -------------------------------------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
         BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
        ,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
        ,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         p.batch_id
        ,'RawToCleaned'
        ,'Policy'
        ,p.RawRowID
        ,p.source_file_name
        ,nullif(trim(p.policy_transaction_id), '')
        ,'policy_id'
        ,p.policy_id
        ,'POL_ID_001'
        ,'Format Validation'
        ,'Error'
        ,'policy_id must follow HS-SS-YY-#####-## format.'
        ,@validation_datetime
    from [Raw].PolicyData p

    where p.batch_id = @batch_id
      and nullif(trim(p.policy_id), '') is not null
      and
      (
           len(trim(p.policy_id)) <> 17
        or substring(trim(p.policy_id), 1, 3) <> 'HS-'
        or substring(trim(p.policy_id), 6, 1) <> '-'
        or substring(trim(p.policy_id), 9, 1) <> '-'
        or substring(trim(p.policy_id), 15, 1) <> '-'
        or substring(upper(trim(p.policy_id)), 4, 2) like '%[^A-Z]%'
        or substring(trim(p.policy_id), 7, 2) like '%[^0-9]%'
        or substring(trim(p.policy_id), 10, 5) like '%[^0-9]%'
        or substring(trim(p.policy_id), 16, 2) like '%[^0-9]%'
      );


    -- Validate policy_id component in schema -> [pgm abbrev]-[state]-[year]-[core acct]-[seq num] -> HS-NY-26-40192-00
    -------------------------------------------------------------------------------------------------------------------------
    -- State
    insert into Ctl.LoadValidationError
    (
         BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
        ,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
        ,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         p.batch_id
        ,'RawToCleaned'
        ,'Policy'
        ,p.RawRowID
        ,p.source_file_name
        ,nullif(trim(p.policy_transaction_id), '')
        ,'state'
        ,p.[state]
        ,'POL_ID_002'
        ,'Relationship Validation'
        ,'Error'
        ,'state does not agree with the state component encoded in policy_id.'
        ,@validation_datetime
    from [Raw].PolicyData p

    where p.batch_id = @batch_id
        and len(trim(p.policy_id)) = 17
        and len(trim(p.[state])) = 2
        and upper(trim(p.[state])) <> substring(upper(trim(p.policy_id)),4,2);

    -- Effective year
    insert into Ctl.LoadValidationError
    (
         BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
        ,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
        ,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         p.batch_id
        ,'RawToCleaned'
        ,'Policy'
        ,p.RawRowID
        ,p.source_file_name
        ,nullif(trim(p.policy_transaction_id), '')
        ,'effective_date'
        ,p.effective_date
        ,'POL_ID_003'
        ,'Relationship Validation'
        ,'Error'
        ,'effective_date year does not agree with the year component encoded in policy_id.'
        ,@validation_datetime
    from [Raw].PolicyData p
    where p.batch_id = @batch_id
      and len(trim(p.policy_id)) = 17
      and try_convert(date, nullif(trim(p.effective_date), ''), 23) is not null
      and right(convert(
                    varchar(4), 
                    year(try_convert(date, trim(p.effective_date),23)))
          , 2) <> substring(trim(p.policy_id), 7, 2);

    -- Core account
    insert into Ctl.LoadValidationError
    (
         BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
        ,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
        ,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         p.batch_id
        ,'RawToCleaned'
        ,'Policy'
        ,p.RawRowID
        ,p.source_file_name
        ,nullif(trim(p.policy_transaction_id), '')
        ,'core_account_number'
        ,p.core_account_number
        ,'POL_ID_004'
        ,'Relationship Validation'
        ,'Error'
        ,'core_account_number does not agree with the account component encoded in policy_id.'
        ,@validation_datetime
    from [Raw].PolicyData p
    where p.batch_id = @batch_id
      and len(trim(p.policy_id)) = 17
      and nullif(trim(p.core_account_number), '') is not null
      and trim(p.core_account_number) <> substring(trim(p.policy_id), 10, 5);

    -- Renewal sequence
    insert Ctl.LoadValidationError
    (
         BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
        ,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
        ,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         p.batch_id
        ,'RawToCleaned'
        ,'Policy'
        ,p.RawRowID
        ,p.source_file_name
        ,nullif(trim(p.policy_transaction_id), '')
        ,'renewal_sequence'
        ,p.renewal_sequence
        ,'POL_ID_005'
        ,'Relationship Validation'
        ,'Error'
        ,'renewal_sequence does not agree with the renewal component encoded in policy_id.'
        ,@validation_datetime
    from [Raw].PolicyData p

    where p.batch_id = @batch_id
      and len(trim(p.policy_id)) = 17
      and try_convert(int, nullif(trim(p.renewal_sequence), '')) is not null
      and try_convert(int, substring(trim(p.policy_id), 16, 2))
          <> try_convert(int, trim(p.renewal_sequence));


    -- Validate effective_date <= expiration_date
    -------------------------------------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
         BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
        ,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
        ,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         p.batch_id
        ,'RawToCleaned'
        ,'Policy'
        ,p.RawRowID
        ,p.source_file_name
        ,nullif(trim(p.policy_transaction_id), '')
        ,'effective_date'
        ,p.effective_date
        ,'POL_DATE_002'
        ,'Business Rule'
        ,'Error'
        ,'effective_date cannot occur after expiration_date.'
        ,@validation_datetime
    from [Raw].PolicyData p

    where p.batch_id = @batch_id
      and try_convert(date, p.effective_date, 23)
          > try_convert(date, p.expiration_date, 23);


    -- Validate retroactive_date <= effective_date
    -------------------------------------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
         BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
        ,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
        ,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         p.batch_id
        ,'RawToCleaned'
        ,'Policy'
        ,p.RawRowID
        ,p.source_file_name
        ,nullif(trim(p.policy_transaction_id), '')
        ,'retroactive_date'
        ,p.retroactive_date
        ,'POL_DATE_003'
        ,'Business Rule'
        ,'Error'
        ,'retroactive_date cannot occur after effective_date.'
        ,@validation_datetime
    from [Raw].PolicyData p

    where p.batch_id = @batch_id
      and try_convert(date, nullif(trim(p.retroactive_date), ''), 23)
          > try_convert(date, nullif(trim(p.effective_date), ''), 23);
    

    -- Policy limit validation
    -------------------------------------------------------------------------------------------------------------------------

    -- occurrence_limit cannot exceed aggregate_limit
    insert into Ctl.LoadValidationError
    (
         BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
        ,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
        ,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         p.batch_id
        ,'RawToCleaned'
        ,'Policy'
        ,p.RawRowID
        ,p.source_file_name
        ,nullif(trim(p.policy_transaction_id), '')
        ,'occurrence_limit'
        ,p.occurrence_limit
        ,'POL_LIMIT_001'
        ,'Business Rule'
        ,'Error'
        ,'occurrence_limit cannot exceed aggregate_limit.'
        ,@validation_datetime
    from [Raw].PolicyData p

    where p.batch_id = @batch_id
      and try_convert(decimal(19,6), nullif(trim(p.occurrence_limit), '')) is not null
      and try_convert(decimal(19,6), nullif(trim(p.aggregate_limit), '')) is not null
      and try_convert(decimal(19,6), trim(p.occurrence_limit))
          > try_convert(decimal(19,6), trim(p.aggregate_limit));

    -- limits or retentions cannot be negative
    insert into Ctl.LoadValidationError
    (
         BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
        ,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
        ,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         p.batch_id
        ,'RawToCleaned'
        ,'Policy'
        ,p.RawRowID
        ,p.source_file_name
        ,nullif(trim(p.policy_transaction_id), '')
        ,v.column_name
        ,v.column_value
        ,'POL_AMT_002'
        ,'Business Rule'
        ,'Error'
        ,concat(v.column_name, ' cannot be negative.')
        ,@validation_datetime
    from [Raw].PolicyData p
    
    cross apply
    (
        values
             ('occurrence_limit',  p.occurrence_limit)
            ,('aggregate_limit',   p.aggregate_limit)
            ,('deductible_amount', p.deductible_amount)
            ,('sir_amount',        p.sir_amount)
    ) v(column_name, column_value)

    where p.batch_id = @batch_id
      and try_convert(decimal(19,6), nullif(trim(v.column_value), '')) < 0;


    -- Validate retension logic
    -------------------------------------------------------------------------------------------------------------------------

    -- allowed retention types
    insert into Ctl.LoadValidationError
    (
         BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
        ,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
        ,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         p.batch_id
        ,'RawToCleaned'
        ,'Policy'
        ,p.RawRowID
        ,p.source_file_name
        ,nullif(trim(p.policy_transaction_id), '')
        ,'retention_type'
        ,p.retention_type
        ,'POL_RET_001'
        ,'Business Rule'
        ,'Error'
        ,'retention_type must be Deductible or SIR when populated.'
        ,@validation_datetime
    from [Raw].PolicyData p

    where p.batch_id = @batch_id
      AND nullif(trim(p.retention_type), '') is not null
      AND upper(trim(p.retention_type)) not in ('DEDUCTIBLE', 'SIR');

    -- Deductible
    insert into Ctl.LoadValidationError
    (
         BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
        ,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
        ,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         p.batch_id
        ,'RawToCleaned'
        ,'Policy'
        ,p.RawRowID
        ,p.source_file_name
        ,nullif(trim(p.policy_transaction_id), '')
        
        ,'deductible_amount'
        ,p.deductible_amount
        ,'POL_RET_002'
        ,'Business Rule'
        ,'Error'
        ,'When retention_type is Deductible, deductible_amount must be populated and sir_amount must be blank.'
        ,@validation_datetime
    from [Raw].PolicyData p

    where p.batch_id = @batch_id
      and upper(trim(p.retention_type)) = 'DEDUCTIBLE'
      and
      (
           try_convert(decimal(19,6), nullif(trim(p.deductible_amount), '')) is null 
           or nullif(trim(p.sir_amount), '') is not null
      );

    -- SIR
    insert into Ctl.LoadValidationError
    (
         BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
        ,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
        ,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         p.batch_id
        ,'RawToCleaned'
        ,'Policy'
        ,p.RawRowID
        ,p.source_file_name
        ,nullif(trim(p.policy_transaction_id), '')
        ,'sir_amount'
        ,p.sir_amount
        ,'POL_RET_003'
        ,'Business Rule'
        ,'Error'
        ,'When retention_type is SIR, sir_amount must be populated and deductible_amount must be blank.'
        ,@validation_datetime
    from [Raw].PolicyData p

    where p.batch_id = @batch_id
      and upper(trim(p.retention_type)) = 'SIR'
      and
      (
           try_convert(decimal(19,6), nullif(trim(p.sir_amount), '')) is null 
           or nullif(trim(p.deductible_amount), '') is not null
      );


    -- Validate transaction type and renewal sequence; new business cannot be > 0 and renewal seq cannot be < 1
    -------------------------------------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
         BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
        ,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
        ,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         p.batch_id
        ,'RawToCleaned'
        ,'Policy'
        ,p.RawRowID
        ,p.source_file_name
        ,nullif(trim(p.policy_transaction_id), '')
        ,'renewal_sequence'
        ,p.renewal_sequence
        ,'POL_TXN_001'
        ,'Business Rule'
        ,'Error'
        ,'transaction_type and renewal_sequence are inconsistent.'
        ,@validation_datetime
    from [Raw].PolicyData p
    where p.batch_id = @batch_id
      and try_convert(int, nullif(trim(p.renewal_sequence), '')) is not null
      and
      (
        (upper(trim(p.transaction_type)) = 'NEW BUSINESS' and try_convert(int, trim(p.renewal_sequence)) <> 0)
        or (upper(trim(p.transaction_type)) = 'RENEWAL' and try_convert(int, trim(p.renewal_sequence)) = 0)
      );


    -- Validate treaty year and effective year
    -------------------------------------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
         BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
        ,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
        ,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         p.batch_id
        ,'RawToCleaned'
        ,'Policy'
        ,p.RawRowID
        ,p.source_file_name
        ,nullif(trim(p.policy_transaction_id), '')
        ,'treaty_year'
        ,p.treaty_year
        ,'POL_YEAR_001'
        ,'Business Rule'
        ,'Error'
        ,'treaty_year does not agree with the effective_date year.'
        ,@validation_datetime
    from [Raw].PolicyData p
    where p.batch_id = @batch_id
      and try_convert(int, nullif(trim(p.treaty_year), '')) is not null
      and try_convert(date, nullif(trim(p.effective_date), ''), 23) is not null
      and try_convert(int, trim(p.treaty_year)) <> year(try_convert(date, trim(p.effective_date), 23));


    -- Validate percentage range
    -------------------------------------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
         BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
        ,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
        ,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         p.batch_id
        ,'RawToCleaned'
        ,'Policy'
        ,p.RawRowID
        ,p.source_file_name
        ,nullif(trim(p.policy_transaction_id), '')
        ,v.column_name
        ,v.column_value
        ,'POL_PCT_002'
        ,'Business Rule'
        ,'Error'
        ,concat(v.column_name, ' must be between 0 and 1.')
        ,@validation_datetime
    from [Raw].PolicyData p
    
    cross apply
    (
        values
             ('broker_premium_%',         p.[broker_premium_%])
            ,('carrier_premium_%',        p.[carrier_premium_%])
            ,('ceding_company_premium_%', p.[ceding_company_premium_%])
            ,('state_premium_tax_%',      p.[state_premium_tax_%])
            ,('mcare_fee_%',              p.[mcare_fee_%])
            ,('policy_fee_%',             p.[policy_fee_%])
            ,('surplus_lines_tax_%',      p.[surplus_lines_tax_%])
            ,('stamping_fee_%',           p.[stamping_fee_%])
            ,('non_carrier_total_%',      p.[non_carrier_total_%])
            ,('allocation_check_%',       p.[allocation_check_%])
    ) v(column_name, column_value)
    where p.batch_id = @batch_id
      and try_convert(decimal(9,6), nullif(trim(v.column_value), '')) is not null
      and
      (
        try_convert(decimal(9,6), trim(v.column_value)) < 0
        or try_convert(decimal(9,6), trim(v.column_value)) > 1
      );

    /*
    -- Amount-to-percentage reconciliation
        $0.02 tolerance for rounding.
        Negative premiums remain valid for cancellation/return transactions.
    -------------------------------------------------------------------------------------------------------------------------
    */
    insert into Ctl.LoadValidationError
    (
         BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
        ,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
        ,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         p.batch_id
        ,'RawToCleaned'
        ,'Policy'
        ,p.RawRowID
        ,p.source_file_name
        ,nullif(trim(p.policy_transaction_id), '')
        ,v.amount_column
        ,v.amount_value
        ,'POL_RECON_001'
        ,'Reconciliation'
        ,'Error'
        ,concat(v.amount_column,' does not reconcile to total_premium * ',v.percent_column,' within $0.02.')
        ,@validation_datetime
    from [Raw].PolicyData p

    cross apply
    (
        values
             ('broker_premium_$',  p.broker_premium_$,
              'broker_premium_%',  p.[broker_premium_%])
            ,('carrier_premium_$', p.carrier_premium_$,
              'carrier_premium_%', p.[carrier_premium_%])
            ,('ceding_premium_$',         p.ceding_premium_$,
              'ceding_company_premium_%', p.[ceding_company_premium_%])
            ,('state_premium_tax',   p.state_premium_tax,
              'state_premium_tax_%', p.[state_premium_tax_%])
            ,('mcare_fee',   p.mcare_fee, 
              'mcare_fee_%', p.[mcare_fee_%])
            ,('policy_fee',   p.policy_fee, 
              'policy_fee_%', p.[policy_fee_%])
            ,('surplus_lines_tax',   p.surplus_lines_tax,
              'surplus_lines_tax_%', p.[surplus_lines_tax_%])
            ,('stamping_fee',   p.stamping_fee,
              'stamping_fee_%', p.[stamping_fee_%])
    ) v(amount_column, amount_value, percent_column, percent_value)
    where p.batch_id = @batch_id
      and try_convert(decimal(19,6), nullif(trim(p.total_premium), '')) is not null
      AND try_convert(decimal(19,6), nullif(trim(v.amount_value), '')) is not null
      AND try_convert(decimal(9,6), nullif(trim(v.percent_value), '')) is not null
      AND abs
          (
              try_convert(decimal(19,6), trim(v.amount_value))
              -
              (
                  try_convert(decimal(19,6), trim(p.total_premium))
                  * try_convert(decimal(9,6), trim(v.percent_value))
              )
          ) > 0.02;


    -- non_carrier_total_% reconciliation
    -------------------------------------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
         BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
        ,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
        ,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         p.batch_id
        ,'RawToCleaned'
        ,'Policy'
        ,p.RawRowID
        ,p.source_file_name
        ,nullif(trim(p.policy_transaction_id), '')
        ,'non_carrier_total_%'
        ,p.[non_carrier_total_%]
        ,'POL_RECON_002'
        ,'Reconciliation'
        ,'Error'
        ,'non_carrier_total_% does not reconcile to the summed non-carrier percentage components.'
        ,@validation_datetime
    from [Raw].PolicyData p

    cross apply
    (
        values
        (
              coalesce(try_convert(decimal(9,6), nullif(trim(p.[broker_premium_%]), '')), 0)
            + coalesce(try_convert(decimal(9,6), nullif(trim(p.[ceding_company_premium_%]), '')), 0)
            + coalesce(try_convert(decimal(9,6), nullif(trim(p.[state_premium_tax_%]), '')), 0)
            + coalesce(try_convert(decimal(9,6), nullif(trim(p.[mcare_fee_%]), '')), 0)
            + coalesce(try_convert(decimal(9,6), nullif(trim(p.[policy_fee_%]), '')), 0)
            + coalesce(try_convert(decimal(9,6), nullif(trim(p.[surplus_lines_tax_%]), '')), 0)
            + coalesce(try_convert(decimal(9,6), nullif(trim(p.[stamping_fee_%]), '')), 0)
        )
    ) calc(expected_non_carrier_total)
    where p.batch_id = @batch_id
      AND try_convert(decimal(9,6), nullif(trim(p.[non_carrier_total_%]), '')) is not null
      AND abs
          (
              try_convert(decimal(9,6), trim(p.[non_carrier_total_%]))
              - calc.expected_non_carrier_total
          ) > 0.000001;


    -- allocation_check_% reconciliation
    -------------------------------------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
         BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
        ,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
        ,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         p.batch_id
        ,'RawToCleaned'
        ,'Policy'
        ,p.RawRowID
        ,p.source_file_name
        ,nullif(trim(p.policy_transaction_id), '')
        ,'allocation_check_%'
        ,p.[allocation_check_%]
        ,'POL_RECON_003'
        ,'Reconciliation'
        ,'Error'
        ,'allocation_check_% does not reconcile to carrier_premium_% + non_carrier_total_%.'
        ,@validation_datetime
    from [Raw].PolicyData p
    where p.batch_id = @batch_id
      and try_convert(decimal(9,6), nullif(trim(p.[allocation_check_%]), '')) is not null
      and try_convert(decimal(9,6), nullif(trim(p.[carrier_premium_%]), '')) is not null
      and try_convert(decimal(9,6), nullif(trim(p.[non_carrier_total_%]), '')) is not null
      and abs
          (
              try_convert(decimal(9,6), trim(p.[allocation_check_%]))
              -
              (
                  try_convert(decimal(9,6), trim(p.[carrier_premium_%]))
                  + try_convert(decimal(9,6), trim(p.[non_carrier_total_%]))
              )
          ) > 0.000001;


    -- Duplicate policy_transaction_id within Raw batch
    -------------------------------------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
         BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
        ,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
        ,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         p.batch_id
        ,'RawToCleaned'
        ,'Policy'
        ,p.RawRowID
        ,p.source_file_name
        ,nullif(trim(p.policy_transaction_id), '')
        ,'policy_transaction_id'
        ,p.policy_transaction_id
        ,'POL_DUP_001'
        ,'Duplicate Validation'
        ,'Error'
        ,'policy_transaction_id appears more than once in the current Raw batch.'
        ,@validation_datetime
    from [Raw].PolicyData p
    where p.batch_id = @batch_id
      and nullif(trim(p.policy_transaction_id), '') is not null
      and exists
      (
          select 1
          from [Raw].PolicyData p2
          where p2.batch_id = p.batch_id
            and p2.RawRowID <> p.RawRowID
            and trim(p2.policy_transaction_id) = trim(p.policy_transaction_id)
      );


    -- Duplicate policy_transaction_id already in Cleaned
    -------------------------------------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
         BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
        ,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
        ,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         p.batch_id
        ,'RawToCleaned'
        ,'Policy'
        ,p.RawRowID
        ,p.source_file_name
        ,nullif(trim(p.policy_transaction_id), '')
        ,'policy_transaction_id'
        ,p.policy_transaction_id
        ,'POL_DUP_002'
        ,'Duplicate Validation'
        ,'Error'
        ,'policy_transaction_id already exists in Cleaned.PolicyData.'
        ,@validation_datetime
    from [Raw].PolicyData p
    where p.batch_id = @batch_id
      and nullif(trim(p.policy_transaction_id), '') is not null
      and exists
      (
          select 1
          from Cleaned.PolicyData cp
          where cp.policy_transaction_id = trim(p.policy_transaction_id)
      );


    -- Duplicate batch
    -------------------------------------------------------------------------------------------------------------------------
    if exists
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
            ,'RawToCleaned'
            ,'Policy'
            ,null
            ,null
            ,null
            ,null
            ,null
            ,'POL_BATCH_002'
            ,'Duplicate Batch'
            ,'Error'
            ,'This Policy batch has already been loaded to Cleaned.'
            ,@validation_datetime
        );
    end;


    -- Nonblocking warning: Claims-Made without retroactive date
    -------------------------------------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
         BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
        ,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
        ,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         p.batch_id
        ,'RawToCleaned'
        ,'Policy'
        ,p.RawRowID
        ,p.source_file_name
        ,nullif(trim(p.policy_transaction_id), '')
        ,'retroactive_date'
        ,p.retroactive_date
        ,'POL_WARN_001'
        ,'Business Rule'
        ,'Warning'
        ,'coverage_basis is Claims-Made but retroactive_date is blank.'
        ,@validation_datetime
    from [Raw].PolicyData p
    where p.batch_id = @batch_id
      and upper(trim(p.coverage_basis)) = 'CLAIMS-MADE'
      and nullif(trim(p.retroactive_date), '') is null;


    -- Stops execution of script if validation errors exist; will return rather than throw
    -------------------------------------------------------------------------------------------------------------------------
    if exists
    (
        select 1
        from Ctl.LoadValidationError
        where BatchID = @batch_id
          and ValidationStage = 'RawToCleaned'
          and EntityName = 'Policy'
          and Severity = 'Error'
    )
    begin
        select
             Severity
            ,ValidationCode
            ,ValidationType
            ,count(*) as ValidationCount
        from Ctl.LoadValidationError
        where BatchID = @batch_id
          and ValidationStage = 'RawToCleaned'
          and EntityName = 'Policy'
        group by
             Severity
            ,ValidationCode
            ,ValidationType
        order by
             case Severity
                 when 'Error' then 1
                 when 'Warning' then 2
                 else 3
             end
            ,ValidationCode;

        select
             ValidationErrorID
            ,BatchID
            ,ValidationStage
            ,EntityName
            ,RawRowID
            ,SourceFileName
            ,RecordIdentifier
            ,ColumnName
            ,InvalidValue
            ,ValidationCode
            ,ValidationType
            ,Severity
            ,ErrorMessage
            ,ValidationDatetime
        from Ctl.LoadValidationError
        where BatchID = @batch_id
          and ValidationStage = 'RawToCleaned'
          and EntityName = 'Policy'
        order by
             case Severity
                 when 'Error' then 1
                 when 'Warning' then 2
                 else 3
             end
            ,SourceFileName
            ,RawRowID
            ,ValidationErrorID;

        return;
    end;


    -- Validation passed; technical/system issues will rollback and throw.
    -------------------------------------------------------------------------------------------------------------------------
    begin try
        begin transaction;

        insert into Cleaned.PolicyData
        (
             policy_transaction_id
            ,policy_id
            ,policyholder_id
            ,insured_name
            ,naics_code
            ,transaction_type
            ,[program_name]
            ,policy_type
            ,coverage_basis
            ,[state]
            ,effective_date
            ,expiration_date
            ,retroactive_date
            ,occurrence_limit
            ,aggregate_limit
            ,retention_type
            ,deductible_amount
            ,sir_amount
            ,core_account_number
            ,renewal_sequence
            ,treaty_year
            ,agency_name
            ,[broker_premium_%]
            ,broker_premium_$
            ,carrier_company_name
            ,[carrier_premium_%]
            ,carrier_premium_$
            ,ceded_from_entity
            ,ceding_company_name
            ,[ceding_company_premium_%]
            ,ceding_premium_$
            ,[state_premium_tax_%]
            ,state_premium_tax
            ,[mcare_fee_%]
            ,mcare_fee
            ,[policy_fee_%]
            ,policy_fee
            ,[surplus_lines_tax_%]
            ,surplus_lines_tax
            ,[stamping_fee_%]
            ,stamping_fee
            ,[non_carrier_total_%]
            ,[allocation_check_%]
            ,total_premium
            ,source_date
            ,tpa_name
            ,source_file_name
            ,raw_load_datetime
            ,clean_load_datetime
            ,batch_id
        )
        SELECT
             trim(p.policy_transaction_id)
            ,trim(p.policy_id)
            ,trim(p.policyholder_id)
            ,trim(p.insured_name)
            ,nullif(trim(p.naics_code), '')
            ,trim(p.transaction_type)
            ,trim(p.[program_name])
            ,trim(p.policy_type)
            ,trim(p.coverage_basis)
            ,upper(trim(p.[state]))
            ,convert(date, trim(p.effective_date), 23)
            ,convert(date, trim(p.expiration_date), 23)
            ,try_convert(date, nullif(trim(p.retroactive_date), ''), 23)
            ,try_convert(decimal(19,6), nullif(trim(p.occurrence_limit), ''))
            ,try_convert(decimal(19,6), nullif(trim(p.aggregate_limit), ''))
            ,nullif(trim(p.retention_type), '')
            ,try_convert(decimal(19,6), nullif(trim(p.deductible_amount), ''))
            ,try_convert(decimal(19,6), nullif(trim(p.sir_amount), ''))
            ,trim(p.core_account_number)
            ,convert(int, trim(p.renewal_sequence))
            ,convert(int, trim(p.treaty_year))
            ,trim(p.agency_name)
            ,try_convert(decimal(9,6), nullif(trim(p.[broker_premium_%]), ''))
            ,try_convert(decimal(19,6), nullif(trim(p.broker_premium_$), ''))
            ,trim(p.carrier_company_name)
            ,try_convert(decimal(9,6), nullif(trim(p.[carrier_premium_%]), ''))
            ,try_convert(decimal(19,6), nullif(trim(p.carrier_premium_$), ''))
            ,nullif(trim(p.ceded_from_entity), '')
            ,nullif(trim(p.ceding_company_name), '')
            ,try_convert(decimal(9,6), nullif(trim(p.[ceding_company_premium_%]), ''))
            ,try_convert(decimal(19,6), nullif(trim(p.ceding_premium_$), ''))
            ,try_convert(decimal(9,6), nullif(trim(p.[state_premium_tax_%]), ''))
            ,try_convert(decimal(19,6), nullif(trim(p.state_premium_tax), ''))
            ,try_convert(decimal(9,6), nullif(trim(p.[mcare_fee_%]), ''))
            ,try_convert(decimal(19,6), nullif(trim(p.mcare_fee), ''))
            ,try_convert(decimal(9,6), nullif(trim(p.[policy_fee_%]), ''))
            ,try_convert(decimal(19,6), nullif(trim(p.policy_fee), ''))
            ,try_convert(decimal(9,6), nullif(trim(p.[surplus_lines_tax_%]), ''))
            ,try_convert(decimal(19,6), nullif(trim(p.surplus_lines_tax), ''))
            ,try_convert(decimal(9,6), nullif(trim(p.[stamping_fee_%]), ''))
            ,try_convert(decimal(19,6), nullif(trim(p.stamping_fee), ''))
            ,try_convert(decimal(9,6), nullif(trim(p.[non_carrier_total_%]), ''))
            ,try_convert(decimal(9,6), nullif(trim(p.[allocation_check_%]), ''))
            ,convert(decimal(19,6), trim(p.total_premium))
            ,convert(date, trim(p.source_date), 23)
            ,p.tpa_name
            ,p.source_file_name
            ,p.raw_load_datetime
            ,@clean_load_datetime
            ,p.batch_id
        from [Raw].PolicyData p
        where p.batch_id = @batch_id;

        commit transaction;
    end try

    begin catch
        if @@TRANCOUNT > 0
            rollback transaction;

        throw;
    end catch;

    -- Successful load results; warning returned even though they do not block load.
    -------------------------------------------------------------------------------------------------------------------------
    select
         @batch_id as BatchID
        ,count(*) as RowsLoaded
        ,@clean_load_datetime as CleanLoadDatetime
    from Cleaned.PolicyData
    where batch_id = @batch_id;

    select
         ValidationErrorID
        ,BatchID
        ,RawRowID
        ,SourceFileName
        ,RecordIdentifier
        ,ColumnName
        ,InvalidValue
        ,ValidationCode
        ,ValidationType
        ,Severity
        ,ErrorMessage
        ,ValidationDatetime
    from Ctl.LoadValidationError
    where BatchID = @batch_id
      and ValidationStage = 'RawToCleaned'
      and EntityName = 'Policy'
      and Severity = 'Warning'
    order by SourceFileName, RawRowID, ValidationErrorID;
end;
go