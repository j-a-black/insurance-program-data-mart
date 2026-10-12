use InsurancePrograms;
GO

/*
----------------------------------------------------------------------------------------------------------------------------------------------
Script Name:
	0010_Create_Schema.Raw.Cleaned.Curated.sql

Purpose:
	Creates the 'Raw', 'Cleaned', and 'Curated' schemas.

----------------------------------------------------------------------------------------------------------------------------------------------
*/

-- Create Raw schema
if SCHEMA_ID('Raw') is null
begin
	exec('create schema Raw');
	print('Raw schema created');
end;

-- Create Cleaned schema
if SCHEMA_ID('Cleaned') is null
begin
	exec('create schema Cleaned');
	print('Cleaned schema created');
end;

-- Create Curated schema
if SCHEMA_ID('Curated') is null
begin
	exec('create schema Curated');
	print('Curated schema created');
end;

-- Create Ctl schema
if SCHEMA_ID('Ctl') is null
begin
	exec('create schema Ctl');
	print('Ctl schema created');
end;