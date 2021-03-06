USE [SportsDB]
GO
/****** Object:  UserDefinedFunction [dbo].[SMG_fnGetSoloResults_Racing_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[SMG_fnGetSoloResults_Racing_XML] (	
    @seasonKey INT,
	@leagueId VARCHAR(100),
	@eventId INT
)
RETURNS XML
AS
-- =============================================
-- Author:      ikenticus
-- Create date: 09/10/2015
-- Description: migrate solo results for racing from sproc to function
-- =============================================
BEGIN
	DECLARE @results_xml XML

	-- get league_key/event_key
    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueId)
	DECLARE @event_type VARCHAR(100) = 'stroke'
	DECLARE @event_name VARCHAR(200)
    DECLARE @event_key VARCHAR(100)
	DECLARE @purse VARCHAR(100)

	SELECT @event_key = event_key, @event_name = event_name, @purse = purse
	  FROM dbo.SMG_Solo_Events
	 WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)

	IF (@purse NOT IN ('$', '$000.00'))
	BEGIN
		SET @event_name = @purse + ' ' + @event_name
	END


	DECLARE @stats TABLE (
		team_key	VARCHAR(100),
		player_key	VARCHAR(100),
		player_name VARCHAR(100),
		[round]		VARCHAR(100),
		[column]	VARCHAR(100),
		value		VARCHAR(MAX)
	)

	INSERT INTO @stats (team_key, player_key, player_name, [round], [column], value)
	SELECT team_key, player_key, player_name, [round], [column], value
	  FROM dbo.SMG_Solo_Results
	 WHERE league_key = @league_key AND season_key = @seasonKey AND event_key = @event_key


	DECLARE @columns TABLE (
		display VARCHAR(100),
		[column] VARCHAR(100)
	)

	DECLARE @results TABLE (
		player_key			VARCHAR(100),
		player_name			VARCHAR(100),
		points				INT,
		qualifying_position	VARCHAR(100),
		vehicle_number		VARCHAR(100),
		vehicle_make		VARCHAR(100),
		laps_completed		INT,
		laps_leading_total	INT,
		status				VARCHAR(100),
		money				VARCHAR(100),
		[rank]				INT
	)

	INSERT INTO @columns (display, [column])
	VALUES
		('RANK', 'rank'), ('DRIVER', 'player_name'),
		('NUM', 'vehicle_number'), ('CAR', 'vehicle_make'),
		('POINTS', 'points'), ('QP', 'qualifying_position'),
		('LAPS COMPLETED', 'laps_completed'), ('LAPS LED', 'laps_leading_total'),
		('STATUS', 'status'), ('MONEY', 'money')

	INSERT INTO @results (player_key, player_name, rank, vehicle_number, vehicle_make, status, money,
						points, qualifying_position, laps_completed, laps_leading_total)
	SELECT p.player_key, p.player_name, [rank], [vehicle-number], [vehicle-make], [status], [money],
						ISNULL([points], 0), [qualifying-position], [laps-completed], [laps-leading-total]
	  FROM (SELECT player_key, player_name, [column], value FROM @stats) AS s
	 PIVOT (MAX(s.value) FOR s.[column] IN ([rank], [vehicle-number], [vehicle-make], [status], [money],
						[points], [qualifying-position], [laps-completed], [laps-leading-total])) AS p

	DELETE @results
	 WHERE status IS NULL

	UPDATE @results
	   SET [rank] = NULL
	 WHERE [rank] = 0

	-- remove dollar sign and cents
	UPDATE @results
	   SET money = REPLACE(REPLACE(money, '$', ''), '.00', '')

	-- STATS lumps the Budweiser Duels and Daytona 500 purses together, unless driver does not qualify for 500
	IF (@event_name LIKE '% Duel %')
	BEGIN
		UPDATE @results
		   SET money = 'Daytona 500'
		 WHERE money = ''
	END

	IF NOT EXISTS (SELECT 1 FROM @results WHERE vehicle_make <> '')
	BEGIN
		DELETE @columns
		 WHERE [column] = 'vehicle_make'
	END

	IF NOT EXISTS (SELECT 1 FROM @results WHERE points IS NOT NULL)
	BEGIN
		DELETE @columns
		 WHERE [column] = 'points'
	END

	IF NOT EXISTS (SELECT 1 FROM @results WHERE laps_leading_total IS NOT NULL)
	BEGIN
		DELETE @columns
		 WHERE [column] = 'laps_leading_total'
	END

	IF NOT EXISTS (SELECT 1 FROM @results WHERE money IS NOT NULL)
	BEGIN
		DELETE @columns
		 WHERE [column] = 'money'
	END

	SELECT @results_xml = (
		SELECT @event_name AS ribbon,
		(
			SELECT
			(
				SELECT display, [column]
				  FROM @columns
				   FOR XML RAW('column'), TYPE
			),
			(
				SELECT player_name, vehicle_number, vehicle_make, status, [rank],
						NULLIF(money, 'TBA') AS money,
						points, qualifying_position, laps_completed, laps_leading_total
				  FROM @results
				 ORDER BY ISNULL(rank, 1000) ASC, qualifying_position ASC
				   FOR XML RAW('row'), TYPE
			)
			FOR XML RAW('table'), TYPE
		)
		FOR XML PATH(''), ROOT('root')
	)
	
	RETURN @results_xml
END

GO
