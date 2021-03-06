USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetTeamRoster_MLB_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SMG_GetTeamRoster_MLB_XML]
	@teamKey VARCHAR(100),
	@seasonKey INT,
	@level VARCHAR(100)
AS
--=============================================
-- Author:	  ikenticus
-- Create date:	09/24/2013
-- Description: get MLB team roster
-- Update:		02/21/2014 - ikenticus: exclude phase_status=delete from query
--				07/02/2014 - ikenticus: updating pitchers to include SP/RP from STATS
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
		('PITCHERS', 'pitchers'),
		('CATCHERS', 'catchers'),
		('INFIELDERS', 'infielders'),
		('OUTFIELDERS', 'outfielders'),
		('DESIGNATED HITTERS', 'designated_hitters')
	

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
		('uniform_number', 'NO', 'Uniform Number', 'asc,desc', 'numeric', 1),
		('full_name', 'NAME', 'Player Name', 'asc,desc', 'string', 2),
		('position_regular', 'POS', 'Position', 'asc,desc', 'string', 3),
		('batting_hand', 'BAT', 'Batting Hand', 'asc,desc', 'string', 4),
		('throwing_hand', 'THROW', 'Throwing Hand', 'asc,desc', 'string', 5),
		('age', 'AGE', 'Age', 'asc,desc', 'numeric', 6),
		('height', 'HT', 'Height', 'asc,desc', 'height', 7),
		('weight', 'WT', 'Weight', 'asc,desc', 'numeric', 8),
		('date_of_birth', 'DOB', 'Date of Birth', 'asc,desc', 'string', 9),
		('status', 'STATUS', 'Status', 'asc,desc', 'string', 10)


	-- roster
	DECLARE @roster TABLE (
		player_key			VARCHAR(100),
		uniform_number		VARCHAR(100),
		full_name			VARCHAR(100),
		position_regular	VARCHAR(100),
		batting_hand		VARCHAR(100),
		throwing_hand		VARCHAR(100),
		height				VARCHAR(100),
		weight				INT,
		age					INT,
		date_of_birth		DATE,
		status				VARCHAR(100)
	)
	INSERT INTO @roster (
		player_key, uniform_number,
		full_name, position_regular,
		batting_hand, throwing_hand,
		height, weight,
		age, date_of_birth,
		status
	) SELECT
		p.player_key,
		ISNULL(NULLIF(r.uniform_number, 0), '--') AS uniform_number,
		p.first_name + ' ' + p.last_name AS full_name,
		r.position_regular,
		p.shooting_batting_hand AS batting_hand,
		p.throwing_hand,
		r.height,
		r.weight,
		DATEDIFF(YY, p.date_of_birth, GETDATE()) AS age,
		p.date_of_birth,
		ISNULL(r.subphase_type, r.phase_status) AS status	
	FROM SportsDB.dbo.SMG_Rosters AS r
	INNER JOIN SportsDB.dbo.SMG_Players AS p
		ON p.player_key = r.player_key
	WHERE r.team_key = @teamKey
		--AND r.league_key = @leagueKey
		AND r.season_key = @seasonKey
		AND r.phase_status <> 'delete'


	-- full roster: additional tables/columns
	DECLARE @tables XML
	IF (@level = 'full')
	BEGIN
		INSERT INTO @reference (ribbon, ribbon_node)
		VALUES
			('INACTIVE', 'inactive'),
			('DISABLED LIST', 'injured'),
			('MINORS', 'minor_league')
		SELECT @tables = (
			SELECT
			(
				SELECT [column], ribbon, display, [sort], [type], [order]
				FROM @columns
				ORDER BY [order]
				FOR XML RAW('inactive_column'), TYPE
			),
			(
				SELECT 
					player_key, uniform_number,
					full_name, position_regular,
					batting_hand, throwing_hand,
					height, weight,
					age, date_of_birth,
					status
				FROM @roster
				WHERE status = 'inactive'
				ORDER BY uniform_number
				FOR XML RAW('inactive'), TYPE
			),
			(
				SELECT [column], ribbon, display, [sort], [type], [order]
				FROM @columns
				ORDER BY [order]
				FOR XML RAW('injured_column'), TYPE
			),
			(
				SELECT 
					player_key, uniform_number,
					full_name, position_regular,
					batting_hand, throwing_hand,
					height, weight,
					age, date_of_birth,
					status
				FROM @roster
				WHERE status = 'injured'
				ORDER BY uniform_number
				FOR XML RAW('injured'), TYPE			),
			(
				SELECT [column], ribbon, display, [sort], [type], [order]
				FROM @columns
				ORDER BY [order]
				FOR XML RAW('minor_league_column'), TYPE
			),
			(
				SELECT 
					player_key, uniform_number,
					full_name, position_regular,
					batting_hand, throwing_hand,
					height, weight,
					age, date_of_birth,
					status
				FROM @roster
				WHERE status = 'minor-league'
				ORDER BY uniform_number
				FOR XML RAW('minor_league'), TYPE
			)
			FOR XML RAW('full'), TYPE
		)
	END


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
		FOR XML RAW('pitchers_column'), TYPE
	),
	(
		SELECT 
			player_key, uniform_number,
			full_name, position_regular,
			batting_hand, throwing_hand,
			height, weight,
			age, date_of_birth,
			status
		FROM @roster
		WHERE status = 'active'
			AND (CASE
				WHEN (CHARINDEX(',', position_regular) = 0) THEN position_regular
				ELSE SUBSTRING(position_regular, 0, PATINDEX('%,%', position_regular))
				END) IN ('P', 'SP', 'RP')
		ORDER BY uniform_number
		FOR XML RAW('pitchers'), TYPE
	),
	(
		SELECT [column], ribbon, display, [sort], [type], [order]
		FROM @columns
		ORDER BY [order]
		FOR XML RAW('catchers_column'), TYPE
	),
	(
		SELECT 
			player_key, uniform_number,
			full_name, position_regular,
			batting_hand, throwing_hand,
			height, weight,
			age, date_of_birth,
			status
		FROM @roster
		WHERE status = 'active'
			AND (CASE
				WHEN (CHARINDEX(',', position_regular) = 0) THEN position_regular
				ELSE SUBSTRING(position_regular, 0, PATINDEX('%,%', position_regular))
				END) = 'C'
		ORDER BY uniform_number
		FOR XML RAW('catchers'), TYPE
	),
	(
		SELECT [column], ribbon, display, [sort], [type], [order]
		FROM @columns
		ORDER BY [order]
		FOR XML RAW('infielders_column'), TYPE
	),
	(
		SELECT 
			player_key, uniform_number,
			full_name, position_regular,
			batting_hand, throwing_hand,
			height, weight,
			age, date_of_birth,
			status
		FROM @roster
		WHERE status = 'active'
			AND (CASE
				WHEN (CHARINDEX(',', position_regular) = 0) THEN position_regular
				ELSE SUBSTRING(position_regular, 0, PATINDEX('%,%', position_regular))
				END) IN ('1B', '2B', 'SS', '3B')
		ORDER BY uniform_number
		FOR XML RAW('infielders'), TYPE
	),
	(
		SELECT [column], ribbon, display, [sort], [type], [order]
		FROM @columns
		ORDER BY [order]
		FOR XML RAW('outfielders_column'), TYPE
	),
	(
		SELECT 
			player_key, uniform_number,
			full_name, position_regular,
			batting_hand, throwing_hand,
			height, weight,
			age, date_of_birth,
			status
		FROM @roster
		WHERE status = 'active'
			AND (CASE
				WHEN (CHARINDEX(',', position_regular) = 0) THEN position_regular
				ELSE SUBSTRING(position_regular, 0, PATINDEX('%,%', position_regular))
				END) IN ('OF', 'LF', 'CF', 'RF')
		ORDER BY uniform_number
		FOR XML RAW('outfielders'), TYPE
	),
	(
		SELECT [column], ribbon, display, [sort], [type], [order]
		FROM @columns
		ORDER BY [order]
		FOR XML RAW('designated_hitters_column'), TYPE
	),
	(
		SELECT 
			player_key, uniform_number,
			full_name, position_regular,
			batting_hand, throwing_hand,
			height, weight,
			age, date_of_birth,
			status
		FROM @roster
		WHERE status = 'active'
			AND (CASE
				WHEN (CHARINDEX(',', position_regular) = 0) THEN position_regular
				ELSE SUBSTRING(position_regular, 0, PATINDEX('%,%', position_regular))
				END) = 'DH'
		ORDER BY uniform_number
		FOR XML RAW('designated_hitters'), TYPE
	),
	(
		SELECT full_name, position_regular
		FROM @roster
		WHERE position_regular = 'Manager'
		FOR XML RAW('manager'), TYPE
	),
	(
		SELECT node.query('inactive_column') FROM @tables.nodes('//full') AS SMG(node)
	),
	(
		SELECT node.query('inactive') FROM @tables.nodes('//full') AS SMG(node)
	),
	(
		SELECT node.query('injured_column') FROM @tables.nodes('//full') AS SMG(node)
	),
	(
		SELECT node.query('injured') FROM @tables.nodes('//full') AS SMG(node)
	),
	(
		SELECT node.query('minor_league_column') FROM @tables.nodes('//full') AS SMG(node)
	),
	(
		SELECT node.query('minor_league') FROM @tables.nodes('//full') AS SMG(node)
	)
	FOR XML RAW('root'), TYPE

	
END


GO
