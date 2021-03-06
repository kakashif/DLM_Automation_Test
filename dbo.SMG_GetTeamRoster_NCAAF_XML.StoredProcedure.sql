USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetTeamRoster_NCAAF_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SMG_GetTeamRoster_NCAAF_XML]
	@teamKey VARCHAR(100),
	@seasonKey INT,
	@level VARCHAR(100)
AS
--=============================================
-- Author:	  ikenticus
-- Create date:	09/28/2013
-- Description: get NCAAF team roster
-- Update:		02/21/2014 - ikenticus: exclude phase_status=delete from query
--				08/08/2014 - ikenticus: switching weight from integer to varchar
--				09/01/2014 - ikenticus: switching uniform from numeric to formatted-number
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


	/*
    -- Determine league key      
	DECLARE @leagueKey VARCHAR(100)
	SET @leagueKey = SUBSTRING(@teamKey, 0, PATINDEX('%-%', @teamKey))
	*/


	-- reference
    DECLARE @reference TABLE (
        ribbon      VARCHAR(100),
        ribbon_node VARCHAR(100)
    )
	INSERT INTO @reference (ribbon, ribbon_node)
	VALUES
		('OFFENSE', 'offense'),
		('DEFENSE', 'defense'),
		('SPECIAL TEAMS', 'special_teams')
	

	-- columns
    DECLARE @columns TABLE (
		[column]	VARCHAR(100),
        ribbon		VARCHAR(100),
		display		VARCHAR(100),
		[sort]		VARCHAR(100),
		[type]		VARCHAR(100),
		[order]		INT
    )
	INSERT INTO @columns ([column], display, ribbon, [sort], [type], [order])
	VALUES
		('uniform_number', 'NO', 'Uniform Number', 'asc,desc', 'formatted-num', 1),
		('full_name', 'NAME', 'Player Name', 'asc,desc', 'string', 2),
		('position_regular', 'POS', 'Position', 'asc,desc', 'string', 3),
		('height', 'HT', 'Height', 'asc,desc', 'height', 4),
		('weight', 'WT', 'Weight', 'asc,desc', 'formatted-num', 5),
		('class', 'CLASS', 'Class', 'asc,desc', 'string', 6),
		('status', 'STATUS', 'Status', 'asc,desc', 'string', 7)


	-- roster
	DECLARE @roster TABLE (
		player_key			VARCHAR(100),
		uniform_number		VARCHAR(100),
		full_name			VARCHAR(100),
		position_regular	VARCHAR(100),
		height				VARCHAR(100),
		weight				VARCHAR(100),
		class				VARCHAR(100),
		status				VARCHAR(100)
	)
	INSERT INTO @roster (
		player_key, uniform_number,
		full_name, position_regular,
		height, weight,
		class, status
	) SELECT
		p.player_key,
		ISNULL(NULLIF(r.uniform_number, 0), '--') AS uniform_number,
		p.first_name + ' ' + p.last_name AS full_name,
		r.position_regular,
		r.height,
		r.weight,
		r.subphase_type,
		r.phase_status
	FROM SportsDB.dbo.SMG_Rosters AS r
	INNER JOIN SportsDB.dbo.SMG_Players AS p
		ON p.player_key = r.player_key
	WHERE r.team_key = @teamKey
		--AND r.league_key = @leagueKey
		AND r.season_key = @seasonKey
		AND r.phase_status <> 'delete'


	-- output XML
	SELECT
	(
		SELECT ribbon, ribbon_node, 'asc' AS [sort], 'uniform_number' AS [column]
		FROM @reference
		FOR XML RAW('reference'), TYPE
	),
	(
		SELECT [column], ribbon, display, [sort], [type], [order]
		FROM @columns
		ORDER BY [order]
		FOR XML RAW('offense_column'), TYPE
	),
	(
		SELECT 
			player_key, uniform_number,
			full_name, position_regular,
			height, weight,
			class, status
		FROM @roster
		WHERE status = 'active'
			AND (CASE
				WHEN (CHARINDEX(',', position_regular) = 0) THEN position_regular
				ELSE SUBSTRING(position_regular, 0, PATINDEX('%/%', position_regular))
				END) IN ('C', 'FB', 'G', 'HB', 'OL', 'QB', 'RB', 'SB', 'TB', 'OT', 'TE', 'WR')
		ORDER BY uniform_number
		FOR XML RAW('offense'), TYPE
	),
	(
		SELECT [column], ribbon, display, [sort], [type], [order]
		FROM @columns
		ORDER BY [order]
		FOR XML RAW('defense_column'), TYPE
	),
	(
		SELECT 
			player_key, uniform_number,
			full_name, position_regular,
			height, weight,
			class, status
		FROM @roster
		WHERE status = 'active'
			AND (CASE
				WHEN (CHARINDEX(',', position_regular) = 0) THEN position_regular
				ELSE SUBSTRING(position_regular, 0, PATINDEX('%/%', position_regular))
				END) IN ('CB', 'DE', 'DB', 'DL', 'DT', 'FS', 'LB', 'NG', 'S', 'SS')
		ORDER BY uniform_number
		FOR XML RAW('defense'), TYPE
	),
	(
		SELECT [column], ribbon, display, [sort], [type], [order]
		FROM @columns
		ORDER BY [order]
		FOR XML RAW('special_teams_column'), TYPE
	),
	(
		SELECT 
			player_key, uniform_number,
			full_name, position_regular,
			height, weight,
			class, status
		FROM @roster
		WHERE status = 'active'
			AND (CASE
				WHEN (CHARINDEX(',', position_regular) = 0) THEN position_regular
				ELSE SUBSTRING(position_regular, 0, PATINDEX('%/%', position_regular))
				END) IN ('LS', 'KR', 'P', 'PK', 'PR')
		ORDER BY uniform_number
		FOR XML RAW('special_teams'), TYPE
	)
	FOR XML RAW('root'), TYPE

	
END


GO
