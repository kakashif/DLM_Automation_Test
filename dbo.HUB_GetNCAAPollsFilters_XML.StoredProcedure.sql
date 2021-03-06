USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetNCAAPollsFilters_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[HUB_GetNCAAPollsFilters_XML]
	@sport VARCHAR(100),
	@poll VARCHAR(100),
	@year INT,
	@week INT
AS
--=============================================
-- Author:	  ikenticus
-- Create date: 08/06/2014
-- Description: get polls filters, clone of SMG_GetPollsFilters, transformed for SportsHub
-- Update:		08/12/2014 - ikenticus: added sports title for title bar
--				09/08/2014 - ikenticus: per JIRA SOC-92, moving BCS polls to bottom and displaying Historical
--				09/09/2014 - ikenticus: per JIRA SN-90, move Coaches Poll above Fan Poll
--				10/10/2014 - ikenticus: per JIRA SOC-114, commenting out Harris Polls as no longer produced
--				10/23/2014 - ikenticus: adding CFP Poll to filter
--				07/01/2015 - ikenticus - adjusting to STATS migration and SMG_Polls* conversion
-- =============================================
BEGIN

	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


-- Sports
	DECLARE @ncaa_sports TABLE (
	    id VARCHAR(100),
	    display VARCHAR(100),
		league_name VARCHAR(100),
		[order] INT
	)
	INSERT INTO @ncaa_sports ([order], id, display, league_name)
	VALUES
		(1, 'football',			'Football',				'ncaaf'),
		(2, 'basketball-men',	'Men''s Basketball',	'ncaab'),
		(3, 'basketball-women',	'Women''s Basketball',	'ncaaw'),
		(4, 'baseball',			'Baseball',				'cws')

	IF (@sport NOT IN (SELECT(id) FROM @ncaa_sports))
	BEGIN
		SET @sport = (SELECT TOP 1 id FROM @ncaa_sports ORDER BY [order] ASC)
	END

	DECLARE @title VARCHAR(100)
	 SELECT @title = display
	   FROM @ncaa_sports
	  WHERE id = @sport


	-- Determine league info from sport
	DECLARE @league_name VARCHAR(100)

	SELECT @league_name = league_name
	  FROM @ncaa_sports
	 WHERE id = @sport


    -- Unsupported league key      
    IF (@league_name NOT IN (
		SELECT league_key
		  FROM SportsEditDB.dbo.SMG_Polls
		 GROUP BY league_key
	))
    BEGIN
		SELECT @league_name = league_name
		  FROM @ncaa_sports
		 WHERE id = 'football'
    END

	DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@league_name)



--- Fixtures
	DECLARE @poll_order TABLE (
		id VARCHAR(100),
		display VARCHAR(100),
		fixture_key VARCHAR(100),
		[order] INT
	)
	INSERT INTO @poll_order ([order], id, fixture_key, display)
	VALUES
		(1, 'coaches-poll',	'smg-usat',		'Coaches Poll'),
		(2, 'fan-poll',		'smg-usatfan',	'Fan Poll'),
		(3, 'cfp-poll',		'poll-cfp',		'College Football Playoff Ranking'),
		(4, 'ap-poll',		'poll-ap',		'AP Poll'),
		(5, 'bcs-poll',		'ranking-bcs',	'Historical BCS Poll')
		--(6, 'harris-poll',	'poll-harris',	'Harris Poll'),

    IF (@league_name <> 'ncaaf')
    BEGIN
        DELETE FROM @poll_order WHERE id IN ('bcs-poll', 'harris-poll', 'fan-poll', 'cfp-poll')
    END

    IF (@league_name = 'cws')
    BEGIN
        DELETE FROM @poll_order WHERE id = 'ap-poll'
    END

    IF (@poll IS NULL OR @poll NOT IN (SELECT(id) FROM @poll_order))
    BEGIN
        SELECT TOP 1 @poll = id
		  FROM @poll_order
		 ORDER BY [order] ASC
    END

	DECLARE @fixture_key VARCHAR(100)
	SELECT @fixture_key = fixture_key
	  FROM @poll_order
	 WHERE id = @poll


--- Sponsors
	DECLARE @sponsor VARCHAR(100)

	SELECT @sponsor = [value]
	  FROM SportsEditDB.dbo.SMG_Data_Front_Attrs
	 WHERE league_name = @league_name
	   AND page_id = 'smg-usat' AND name = 'sponsor'

	IF (@sponsor IS NOT NULL)
	BEGIN
		UPDATE @poll_order
		   SET display = @sponsor + ' ' + display
		 WHERE id IN ('coaches-poll', 'fan-poll')
	END


--- Seasons
    DECLARE @seasons TABLE (
	    id INT,
	    display VARCHAR(100)
	)

	IF (@league_key = 'l.ncaa.org.mbase')
	BEGIN
		INSERT INTO @seasons
		SELECT season_key AS id,
			   CONVERT(VARCHAR(100), season_key) AS display
		  FROM SportsEditDB.dbo.SMG_Polls
		 WHERE fixture_key = @fixture_key AND league_key = @league_name
		   AND (publish_date_time IS NULL OR publish_date_time < GETDATE())
		 GROUP BY season_key
	END
	ELSE
	BEGIN
		IF (@fixture_key = 'smg-usatfan')
		BEGIN
			INSERT INTO @seasons
			SELECT season_key AS id,
				   (CONVERT(VARCHAR(100), season_key) + '-' + RIGHT(CONVERT(VARCHAR(100), season_key + 1), 2)) AS display
			  FROM SportsEditDB.dbo.SMG_Polls
			 WHERE fixture_key = @fixture_key AND league_key = @league_name
			 GROUP BY season_key
		END
		ELSE
		BEGIN
			INSERT INTO @seasons
			SELECT season_key AS id,
				   (CONVERT(VARCHAR(100), season_key) + '-' + RIGHT(CONVERT(VARCHAR(100), season_key + 1), 2)) AS display
			  FROM SportsEditDB.dbo.SMG_Polls
			 WHERE fixture_key = @fixture_key AND league_key = @league_name
			   AND (publish_date_time IS NULL OR publish_date_time < GETDATE())
			 GROUP BY season_key
		END
	END

	DECLARE @team_seasons TABLE (season_key INT)
	 INSERT INTO @team_seasons
	 SELECT season_key FROM SMG_Teams WHERE league_key = @league_key GROUP BY season_key

	DELETE FROM @seasons WHERE id NOT IN (SELECT season_key FROM @team_seasons)

	IF (@year IS NULL OR @year > (SELECT MAX(id) FROM @seasons))
	BEGIN
		SET @year = (SELECT MAX(id) FROM @seasons)
	END

	IF (@year < (SELECT MIN(id) FROM @seasons))
	BEGIN
		SET @year = (SELECT MIN(id) FROM @seasons)
	END

	IF (@year > YEAR(GETDATE()))
	BEGIN
		SET @year = YEAR(GETDATE())
	END

	DECLARE @max_season INT
	SELECT @max_season = MAX(id) FROM @seasons


--- Weeks
    DECLARE @weeks TABLE (
	    id INT,
	    display VARCHAR(100),
		poll_date VARCHAR(100)
	)


	IF (@fixture_key = 'smg-usatfan')
	BEGIN
		INSERT INTO @weeks (id, display, poll_date)
		SELECT [week], 'Week ' + CAST([week] AS VARCHAR), poll_date
		  FROM SportsEditDB.dbo.SMG_Polls
		 WHERE fixture_key = @fixture_key AND league_key = @league_name AND season_key = @year AND week IS NOT NULL
		 GROUP BY season_key, [week], poll_date	
	END
	ELSE
	BEGIN
		INSERT INTO @weeks (id, display, poll_date)
		SELECT [week], 'Week ' + CAST([week] AS VARCHAR), poll_date
		  FROM SportsEditDB.dbo.SMG_Polls
		 WHERE fixture_key = @fixture_key AND league_key = @league_name AND season_key = @year
		   AND (publish_date_time IS NULL OR publish_date_time < GETDATE())
		 GROUP BY season_key, [week], poll_date
	END

    DECLARE @max_week INT
    
    SELECT TOP 1 @max_week = id
      FROM @weeks
     ORDER BY id DESC

    UPDATE @weeks
       SET display = 'Preseason'
     WHERE id = 1
         
    IF (@league_key = 'l.ncaa.org.mfoot')
    BEGIN        
        UPDATE @weeks
           SET display = 'Final Ranking'
         WHERE id >= 16 AND id = @max_week
    END
    ELSE IF (@league_key = 'l.ncaa.org.mbase')
    BEGIN        
        UPDATE @weeks
           SET display = 'Postseason'
         WHERE id >= 15 AND id = @max_week
    END
    ELSE
    BEGIN
        UPDATE @weeks
           SET display = 'Postseason'
         WHERE id = 20

        UPDATE @weeks
           SET display = 'Postseason (Final)'
         WHERE id >= 21 AND id = @max_week
    END

	IF (@week IS NULL OR @week NOT IN (SELECT id FROM @weeks))
	BEGIN
		SET @week = (SELECT MAX(id) FROM @weeks)
	END

	IF (@week IS NULL)
	BEGIN
		SET @week = 1
	END

	DECLARE @end_date_time DATETIME
	IF (@fixture_key = 'smg-usatfan')
	BEGIN
		SELECT TOP 1 @end_date_time = publish_date_time
		  FROM SportsEditDB.dbo.SMG_Polls
		 WHERE league_key = @league_name AND fixture_key = @fixture_key AND season_key = @year AND week = @week
	END

	DECLARE @published_on VARCHAR(100)
	SELECT @published_on = poll_date
	  FROM @weeks
	 WHERE @week = id


	-- Correctly display Fan Poll published on and end_date_time
	IF (@poll = 'fan-poll')
	BEGIN
		SET @published_on = CAST(@end_date_time AS DATE)
		SET @end_date_time = ISNULL(@end_date_time, DATEADD(DD, 5, GETDATE()))
	END
	ELSE
	BEGIN
		SET @end_date_time = NULL
	END


--- XML Output

    ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
    SELECT 
			@published_on AS published_on, 
			@end_date_time AS end_date_time,
			(
				SELECT id, display
				FROM @ncaa_sports
				ORDER BY [order] ASC
				FOR XML RAW('sport'), TYPE
			),
			(
				SELECT 'true' AS 'json:Array', id, display
				  FROM @poll_order
				 ORDER BY [order] ASC
				   FOR XML RAW('poll'), TYPE
			),
			(
				SELECT 'true' AS 'json:Array', id, display
				  FROM @seasons
				 ORDER BY id DESC
				   FOR XML RAW('year'), TYPE
			),
			(
				SELECT 'true' AS 'json:Array', id, display, poll_date
				  FROM @weeks
				 ORDER BY id ASC
				   FOR XML RAW('week'), TYPE
			),
			(
				SELECT display, @league_name AS league, @title AS title,
					   @sport AS [sport], @poll AS [poll], @year AS [year], @week AS [week]
				  FROM @poll_order
				 WHERE id = @poll
				   FOR XML RAW('default'), TYPE
			)    
       FOR XML RAW('root'), TYPE

	SET NOCOUNT OFF;
END




GO
