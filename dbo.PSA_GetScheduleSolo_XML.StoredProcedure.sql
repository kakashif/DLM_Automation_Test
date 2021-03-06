USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetScheduleSolo_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetScheduleSolo_XML]
   @swipe VARCHAR(100),
   @leagueName VARCHAR(100),
   @leagueId VARCHAR(100),
   @year INT,
   @month INT
AS
--=============================================
-- Author:		ikenticus
-- Create date:	07/11/2014
-- Description:	get solo date schedule for jameson
-- Update:		08/19/2014 - ikenticus: adding missing selected key
--				09/02/2014 - ikenticus - utilizing full season schedule per JIRA SJ-110
--				09/04/2014 - ikenticus - adding selected for first upcoming year/month not current
--				09/08/2014 - ikenticus - adding share_link
--              09/29/2014 - John Lin - force sort by
--              10/02/2014 - ikenticus - adding MMA, fixing logic to include future
--              10/09/2014 - ikenticus - adjusting MMA with league_keys from ingestion
--				10/14/2014 - ikenticus - adjusting season_key with provided year to get PGA 2015 schedule correct
--				10/20/2014 - ikenticus - additional season_key adjustments for PGA Tour season starting in October
--				10/30/2014 - ikenticus - fixing Camping World display since Craftsman stopped sponsoring in 2008
--				10/31/2014 - ikenticus - replacing COUNT(*) with EXISTS, fixing default selected, selecting latest season_key
--				11/07/2014 - ikenticus - fixing missing display lost when cleaning out old swipe code
--				11/11/2014 - ikenticus - SJ-584, fixing incorrected selected month when year/month specified
--				11/20/2014 - ikenticus - SJ-584, restricting season to latest season centered around current month
--				12/01/2014 - ikenticus - SJ-1030, default solo schedule not displaying
--				01/12/2015 - ikenticus - SJ-1184, using same logic as PSA_GetFilterSolo for season_key
--				01/14/2015 - ikenticus - more adjustments for NASCAR series change logic
--				01/30/2015 - ikenticus - using league display for Golf instead of hard-coding
--				03/04/2015 - ikenticus - correcting default month for MMA
--				03/26/2015 - ikenticus - adding motor
--				04/16/2015 - ikenticus: adding stats_switch to cutover to STATS when data ingestion complete
--				04/27/2015 - ikenticus: replacing stats_switch with source from SMG_Default_Dates/SMG_Mappings
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


    DECLARE @months TABLE
    (
        display VARCHAR(100),
        scores_endpoint VARCHAR(100),
        [year] INT,
		[month] INT,
		selected INT
    )


	IF (@leagueName = 'mma')
	BEGIN
		DECLARE @this_month DATE = DATEADD(DAY, 1 - DAY(GETDATE()), GETDATE())
		DECLARE @next_month DATE = DATEADD(MONTH, 1, @this_month)

		IF (@year = 0 OR @month = 0 OR @year IS NULL OR @month IS NULL)
		BEGIN
			SELECT TOP 1 @year = YEAR(start_date_time), @month = MONTH(start_date_time)
			  FROM dbo.SMG_Solo_Events AS e
			 INNER JOIN dbo.SMG_Solo_Leagues AS l ON league_name = @leagueName
			   AND l.league_key = e.league_key AND l.season_key = e.season_key
			 WHERE start_date_time BETWEEN @this_month AND @next_month
			 ORDER BY start_date_time ASC
		END

		IF (@year = 0 OR @month = 0 OR @year IS NULL OR @month IS NULL)
		BEGIN
			SELECT TOP 1 @year = YEAR(start_date_time), @month = MONTH(start_date_time)
			  FROM dbo.SMG_Solo_Events AS e
			 INNER JOIN dbo.SMG_Solo_Leagues AS l ON league_name = @leagueName
			   AND l.league_key = e.league_key AND l.season_key = e.season_key
			 WHERE start_date_time < GETDATE()
			 ORDER BY start_date_time DESC
		END

		INSERT INTO @months ([year], [month])
		SELECT YEAR(start_date_time), MONTH(start_date_time)
		  FROM dbo.SMG_Solo_Events AS e
		 INNER JOIN dbo.SMG_Solo_Leagues AS l ON league_name = @leagueName
		   AND l.league_key = e.league_key AND l.season_key = e.season_key
		 WHERE e.season_key = @year
		 GROUP BY YEAR(start_date_time), MONTH(start_date_time)
		 ORDER BY YEAR(start_date_time) ASC, MONTH(start_date_time) ASC
	END
	ELSE
	BEGIN
		IF (@leagueId IS NULL OR @leagueId = '')
		BEGIN
			DECLARE @default_league_id TABLE (
				league_id	VARCHAR(100),
				league_name	VARCHAR(100)
			)

			INSERT INTO @default_league_id (league_name, league_id)
			VALUES	('golf', 'pga-tour'),
					('motor', 'indycar'),
					('nascar', 'cup-series'),
					('tennis', 'mens-tennis')

			SELECT @leagueId = league_id
			  FROM @default_league_id
			 WHERE league_name = LOWER(@leagueName)
		END

		DECLARE @league_source VARCHAR(100)
		DECLARE @league_key VARCHAR(100)

		SELECT TOP 1 @league_source = filter
		  FROM dbo.SMG_Default_Dates
		 WHERE page = 'source' AND league_key = @leagueName

		IF (@league_source IS NOT NULL)
		BEGIN
			SELECT TOP 1 @league_key = value_from
			  FROM dbo.SMG_Mappings
			 WHERE value_type = 'league' AND value_to = @leagueId AND source = @league_source
		END
		ELSE
		BEGIN
			SELECT TOP 1 @league_key = league_key
			  FROM SMG_Solo_Leagues
			 WHERE league_name = LOWER(@leagueName) AND league_id = @leagueId AND league_key LIKE 'l.%'
			 ORDER BY league_id ASC
		END

		DECLARE @season_key INT
		DECLARE @start_date_time DATETIME

		IF (@year = 0 OR @month = 0 OR @year IS NULL OR @month IS NULL)
		BEGIN
			SET @start_date_time = GETDATE()
		END
		ELSE
		BEGIN
			SET @start_date_time = CAST(@year AS VARCHAR) + '-' + CAST(@month AS VARCHAR) + '-1'
		END

		SELECT TOP 1 @season_key = season_key
		  FROM dbo.SMG_Solo_Events
		 WHERE league_key = @league_key AND DATEDIFF(MM, @start_date_time, start_date_time) BETWEEN -1 AND 1
		 ORDER BY start_date_time DESC

		-- Select latest from past using start_date_time
		IF (@season_key IS NULL)
		BEGIN
			SELECT TOP 1 @season_key = season_key
			  FROM dbo.SMG_Solo_Events
			 WHERE league_key = @league_key AND start_date_time < GETDATE()
			 ORDER BY start_date_time DESC
		END

		-- Select next from future using start_date_time
		IF (@season_key IS NULL)
		BEGIN
			SELECT TOP 1 @season_key = season_key
			  FROM dbo.SMG_Solo_Events
			 WHERE league_key = @league_key
			 ORDER BY start_date_time ASC
		END

		INSERT INTO @months ([year], [month])
		SELECT YEAR(start_date_time), MONTH(start_date_time)
		  FROM dbo.SMG_Solo_Events
		 WHERE league_key = @league_key AND season_key = @season_key
		 GROUP BY YEAR(start_date_time), MONTH(start_date_time)
		 ORDER BY YEAR(start_date_time) ASC, MONTH(start_date_time) ASC
	END


	-- Correctly identify selected
	UPDATE @months
	   SET selected = 1
	 WHERE year = @year AND month = @month

	DECLARE @date DATE
	IF (@year = 0 OR @month = 0)
	BEGIN
		SET @date = GETDATE()
	END
	ELSE
	BEGIN
		SET @date = CAST(CAST(@year AS VARCHAR) + '-' + CAST(@month AS VARCHAR) + '-1' AS DATE)
	END

	IF (NOT EXISTS(SELECT 1 FROM @months WHERE selected = 1))
	BEGIN
		DECLARE @past_year INT
		DECLARE @past_month INT
		SELECT TOP 1 @past_year = year, @past_month = month
		  FROM @months
		 WHERE CAST(CAST(year AS VARCHAR) + '-' + CAST(month AS VARCHAR) + '-1' AS DATE) < @date
		 ORDER BY [year] DESC, [month] DESC

		UPDATE @months
		   SET selected = 1
		 WHERE year = @past_year AND month = @past_month
	END

	IF (NOT EXISTS(SELECT 1 FROM @months WHERE selected = 1))
	BEGIN
		DECLARE @upcoming_year INT
		DECLARE @upcoming_month INT
		SELECT TOP 1 @upcoming_year = year, @upcoming_month = month
		  FROM @months
		 WHERE CAST(CAST(year AS VARCHAR) + '-' + CAST(month AS VARCHAR) + '-1' AS DATE) > @date
		 ORDER BY [year] ASC, [month] ASC

		UPDATE @months
		   SET selected = 1
		 WHERE year = @upcoming_year AND month = @upcoming_month
	END


	UPDATE @months
	   SET display = LEFT(DATENAME(MONTH, CAST((CAST([year] AS VARCHAR) + '-' + CAST([month] AS VARCHAR) + '-1') AS DATE)), 3)

	UPDATE @months
	   SET scores_endpoint = '/Scores.svc/' + @leagueName + '/' + @leagueId + '/' + CAST([year] AS VARCHAR) + '/' + CAST(month AS VARCHAR)

	UPDATE @months
	   SET scores_endpoint = '/Scores.svc/' + @leagueName + '/' + CAST([year] AS VARCHAR) + '/' + CAST(month AS VARCHAR)
	 WHERE @leagueId = ''

    DECLARE @previous_endpoint VARCHAR(100)
    DECLARE @next_endpoint VARCHAR(100)

    UPDATE @months
       SET selected = 0
     WHERE selected IS NULL OR selected <> 1


	-- standings
    DECLARE @button_endpoint VARCHAR(100) = '/Standings.svc/' + @leagueName + '/' + @leagueId
    DECLARE @share_link VARCHAR(100)

    DECLARE @button_display VARCHAR(100)
	IF (@leagueName IN ('nascar'))
	BEGIN
		SET @button_display = 'Standings'
		SET @share_link = 'http://www.usatoday.com/sports/' + @leagueName + '/standings/'
	END
	ELSE IF (@leagueName IN ('mma'))
	BEGIN
		SET @button_display = NULL
		SET @button_endpoint = NULL
		SET @share_link = NULL
	END
	ELSE
	BEGIN
		SET @button_display = 'Rankings'
	END


	DECLARE @ribbon VARCHAR(100)

	SELECT TOP 1 @ribbon = league_display
	  FROM SportsDB.dbo.SMG_Solo_Leagues
	 WHERE league_name = @leagueName AND league_id = @leagueId AND season_key = @season_key


    ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
	SELECT	(
				SELECT @previous_endpoint AS previous_endpoint, @next_endpoint AS next_endpoint, @ribbon AS ribbon,
					(
						SELECT 'true' AS 'json:Array',
								display, scores_endpoint, selected
						  FROM @months
						 ORDER BY [year] ASC, [month] ASC
						   FOR XML RAW('entries'), TYPE
					)
				   FOR XML RAW('schedule'), TYPE
			),
			(
				SELECT @button_display AS display, @button_endpoint AS [endpoint], @share_link AS share_link
				   FOR XML RAW('button'), TYPE
			)
	   FOR XML PATH(''), ROOT('root')
	
END

GO
