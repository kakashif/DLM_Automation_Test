USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetEventBriefSolo_Motor_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetEventBriefSolo_Motor_XML] 
	@leagueId VARCHAR(100),
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author:      ikenticus
-- Create date: 03/26/2015
-- Description: get event brief for motor, cloned from nascar
--				04/27/2015 - ikenticus: replacing stats_switch with source from SMG_Default_Dates/SMG_Mappings
--				06/11/2015 - ikenticus: using new league_key function
--				07/17/2016 - ikenticus: optimizing by replacing table calls with temp table
--				07/21/2015 - ikenticus: solo sports failover event_id logic similar to team sports
--				10/07/2015 - ikenticus: fixing UTC conversion
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueId)
    DECLARE @event_key VARCHAR(100)
    DECLARE @event_status VARCHAR(100)
    DECLARE @tv_coverage VARCHAR(100)
    DECLARE @start_date_time_EST DATETIME
    DECLARE @start_date_time_UTC DATETIME
    DECLARE @game_status VARCHAR(100)
    DECLARE @site_name VARCHAR(100)
    DECLARE @ribbon VARCHAR(100)
    DECLARE @sub_ribbon VARCHAR(100)
	DECLARE @total INT
    DECLARE @detail_endpoint VARCHAR(100)

	SET @detail_endpoint = '/Event.svc/detail/motor/' + @leagueId + '/' + CAST(@seasonKey AS VARCHAR) + '/' + CAST(@eventId AS VARCHAR)

	SELECT @event_key = event_key, @event_status = event_status, @tv_coverage = tv_coverage,
		   @start_date_time_EST = start_date_time, @ribbon = event_name, @total = site_count, @site_name = site_name
	  FROM dbo.SMG_Solo_Events
	 WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)

	IF (@event_key IS NULL)
	BEGIN
		-- Failover during source transitions
		SELECT TOP 1 @league_key = league_key,
			   @event_key = event_key, @event_status = event_status, @tv_coverage = tv_coverage,
			   @start_date_time_EST = start_date_time, @ribbon = event_name, @total = site_count, @site_name = site_name
		  FROM dbo.SMG_Solo_Events AS e
		 INNER JOIN SportsDB.dbo.SMG_Mappings AS m ON m.value_from = e.league_key AND m.value_to = @leagueId AND m.value_type = 'league'
		 WHERE season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)
		 ORDER BY league_key DESC
	END

	SET @start_date_time_UTC = DATEADD(HOUR, DATEDIFF(HOUR, GETDATE(), GETUTCDATE()), @start_date_time_EST)

	DECLARE @columns TABLE (
		display		VARCHAR(100),
		[column]	VARCHAR(100),
		[order]		INT
	)

	DECLARE @stats TABLE (
		player_key	VARCHAR(100),
		player_name	VARCHAR(100),
		[column]	VARCHAR(100), 
		value		VARCHAR(100)
	)

	DECLARE @leaders TABLE (
		event_key		VARCHAR(100),
		driver			VARCHAR(100),
		rank			INT,
		points			INT,
		laps_complete	INT,
		laps_behind		VARCHAR(100),
		laps_led		INT
	)

	IF (@event_status = 'pre-event')
	BEGIN
		SET @game_status = CONVERT(VARCHAR, CAST(@start_date_time_EST AS TIME), 100) + ' ET'
		SET @sub_ribbon = @site_name
	END
	ELSE
	BEGIN
		DECLARE @done INT

		INSERT INTO @stats (player_key, player_name, [column], value)
		SELECT player_key, player_name, [column], value 
		  FROM dbo.SMG_Solo_Leaders
		 WHERE event_key = @event_key

		SELECT @done = MAX(CAST(value AS INT))
		  FROM @stats
		 WHERE [column] = 'laps-completed'

		IF (@event_status = 'post-event')
		BEGIN
			SET @game_status = 'Completed'

			INSERT INTO @columns (display, [column], [order])
			VALUES ('POS', 'rank', 1), ('DRIVER', 'driver', 2), ('PTS', 'points', 3), ('LED', 'laps_led', 4)
		END
		ELSE
		BEGIN
			IF (@total IS NOT NULL AND @done IS NOT NULL)
			BEGIN
				SET @game_status = 'Lap ' + CAST(@done AS VARCHAR) + ' of ' + CAST(@total AS VARCHAR)
			END

			INSERT INTO @columns (display, [column], [order])
			VALUES ('POS', 'rank', 1), ('DRIVER', 'driver', 2), ('BEHIND', 'laps_behind', 3), ('LED', 'laps_led', 4)
		END

		INSERT INTO @leaders (rank, points, laps_led, laps_complete, laps_behind, driver)
		SELECT rank, points, [laps-leading-total], [laps-completed], [laps-behind],
			   LEFT(p.player_name, 1) + '. ' + RIGHT(p.player_name, LEN(p.player_name) - CHARINDEX(' ', p.player_name)) + ' (' + p.[vehicle-number] + ')'
		  FROM (SELECT player_key, player_name, [column], value FROM @stats) AS s
		 PIVOT (MAX(s.value) FOR s.[column] IN (rank, [vehicle-number], points, [laps-leading-total], [laps-completed], [laps-behind])) AS p
		 ORDER BY rank

		DELETE @leaders
		 WHERE laps_complete = 0
	END

    SELECT
	(
        SELECT @event_status AS event_status, @tv_coverage AS tv_coverage, @start_date_time_EST AS start_date_time_EST,
               @start_date_time_UTC AS start_date_time_UTC, @ribbon AS ribbon, @sub_ribbon AS sub_ribbon,
               @game_status AS game_status, @detail_endpoint AS detail_endpoint, 'motor' AS league_name,
			(
				SELECT display, [column]
				  FROM @columns
				 ORDER BY [order] ASC
				   FOR XML RAW('columns'), TYPE	
			),
			(
				SELECT rank, points, laps_led, laps_complete, laps_behind, driver
				  FROM @leaders
				   FOR XML RAW('rows'), TYPE	
			)
           FOR XML RAW('brief'), TYPE
    )
    FOR XML PATH(''), ROOT('root')

        
    SET NOCOUNT OFF;
END

GO
