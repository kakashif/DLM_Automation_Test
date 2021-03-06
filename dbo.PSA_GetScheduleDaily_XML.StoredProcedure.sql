USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetScheduleDaily_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PSA_GetScheduleDaily_XML]
   @swipe VARCHAR(100),
   @leagueName VARCHAR(100),
   @year INT,
   @month INT,
   @day INT,
   @filter VARCHAR(100) = NULL
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 06/12/2014
  -- Description: get date schedule for jameson
  -- Update:      08/20/2014 - ikenticus - adding hack to navigate to previous/next season for DEV testing
  --			  08/21/2014 - ikenticus - adding ribbon in schedule node to display filter
  --			  09/02/2014 - ikenticus - utilizing full season schedule per JIRA SJ-110
  --			  09/04/2014 - ikenticus - adding selected for first upcoming date when not today
  --			  09/08/2014 - ikenticus - adding share_link
  --			  09/11/2014 - ikenticus - adding selected logic correctly
  --              09/24/2014 - ikenticus - adding soccer ribbon
  --              09/29/2014 - John Lin - force sort by
  --              10/21/2014 - ikenticus - elimination sport playoff
  --              11/24/2014 - John Lin - use SMG_Default_Dates for default date
  --              12/04/2014 - John Lin - default date vs today
  --              12/08/2014 - John Lin - add ncaaf
  --              12/12/2014 - John Lin - bowls and playoffs render ranking
  --              12/16/2014 - John Lin - ncaaf default to bowls
  --              12/18/2014 - John Lin - add playoffs to ribbon
  --              12/19/2014 - John Lin - no filtering for top25, no set to Today if round
  --              01/26/2015 - ikenticus - bowls/playoffs display null offseason, added logic to display last game
  --              03/16/2015 - John Lin - tourney becomes ncaa
  --              08/12/2015 - ikenticus - adding euro soccer for daily + playoff into the MLS block
  --              10/14/2015 - John Lin - SDI migration
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    IF (@leagueName NOT IN ('mlb', 'mls', 'nba', 'ncaab', 'ncaaf', 'ncaaw', 'nhl', 'wnba', 'epl', 'champions', 'natl', 'wwc'))
    BEGIN
        RETURN
    END

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @default_date DATE
    DECLARE @today DATE = CAST(GETDATE() AS DATE)

    IF (@leagueName = 'ncaab' AND @year = 0 AND @month = 0 AND @day = 0)
    BEGIN        
        SELECT @default_date = [start_date]
          FROM dbo.SMG_Default_Dates
         WHERE league_key = 'ncaab' AND page = 'scores'
        
        SET @year = YEAR(@default_date)
        SET @month = MONTH(@default_date)
        SET @day = DAY(@default_date)
    END
    ELSE IF (@leagueName = 'ncaaf' AND @month = 0 AND @day = 0)    
    BEGIN
        SELECT TOP 1 @default_date = CAST(start_date_time_EST AS DATE)
          FROM dbo.SMG_Schedules
         WHERE league_key = @league_key AND season_key = @year AND [week] = @filter AND start_date_time_EST > @today
         ORDER BY start_date_time_EST ASC

		-- offseason, past bowls/playoffs
		IF (@default_date IS NULL)
		BEGIN
			SELECT TOP 1 @default_date = CAST(start_date_time_EST AS DATE)
			  FROM dbo.SMG_Schedules
			 WHERE league_key = @league_key AND season_key = @year AND [week] = @filter
			 ORDER BY start_date_time_EST DESC
		END

        SET @year = YEAR(@default_date)
        SET @month = MONTH(@default_date)
        SET @day = DAY(@default_date)
    END
    ELSE
    BEGIN
        SELECT @default_date = [start_date]
          FROM dbo.SMG_Default_Dates
         WHERE league_key = @leagueName AND page = 'scores'
    END

    DECLARE @date DATE = CAST(CAST(@year AS VARCHAR) + '-' + CAST(@month AS VARCHAR) + '-' + CAST(@day AS VARCHAR) AS DATE)
    DECLARE @season_key INT
	DECLARE @ribbon VARCHAR(100)
    DECLARE @button_display VARCHAR(100) = 'Standings'
    DECLARE @button_endpoint VARCHAR(100) = '/Standings.svc/' + @leagueName
    DECLARE @share_link VARCHAR(100) = 'http://www.usatoday.com/sports/' + @leagueName + '/standings/'


    SELECT TOP 1 @season_key = season_key
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND start_date_time_EST > @date AND event_status <> 'smg-not-played'
     ORDER BY season_key ASC

	DECLARE @dates TABLE
	(
        [date] DATE,
        display VARCHAR(100),
        scores_endpoint VARCHAR(100),
        selected VARCHAR(100),
        level_id VARCHAR(100)
	)
    DECLARE @elimination TABLE
    (
        [date]   DATE,
        level_id VARCHAR(100),
        selected INT,
        team_key VARCHAR(100)
    )


/* BEGIN FULL SEASON SCHEDULE */

	IF (@leagueName IN ('mls', 'champions', 'natl', 'wwc', 'epl'))
	BEGIN
	    INSERT INTO @dates ([date], level_id, display)
    	SELECT CAST(start_date_time_EST AS DATE), level_id, level_name
	      FROM dbo.SMG_Schedules
    	 WHERE league_key = @league_key AND season_key = @season_key AND event_status <> 'smg-not-played'
	     GROUP BY CAST(start_date_time_EST AS DATE), level_id, level_name
    	 ORDER BY CAST(start_date_time_EST AS DATE) ASC

        UPDATE @dates
           SET level_id = NULL
         WHERE ISNUMERIC(level_id) = 1

		INSERT INTO @elimination ([date], level_id, selected)
		SELECT MAX([date]), level_id, MAX(ISNULL(selected, 0))
		  FROM @dates
		 WHERE level_id IS NOT NULL
		 GROUP BY level_id

        DELETE d
          FROM @dates d
         INNER JOIN @elimination e
            ON e.level_id = d.level_id AND e.[date] <> d.[date]

        UPDATE @dates
		   SET scores_endpoint = '/Scores.svc/' + @leagueName + '/' + CAST(@season_key AS VARCHAR) + '/' + level_id
		 WHERE level_id IS NOT NULL
	END
	ELSE IF (@leagueName = 'ncaab')
	BEGIN
	    IF (@filter = 'tourney')
	    BEGIN
	        SET @filter = 'ncaa'
	    END
	    
	    IF (@filter = 'ncaa')
	    BEGIN
    	    INSERT INTO @dates ([date], level_id, display)
        	SELECT CAST(start_date_time_EST AS DATE), level_id, level_name
	          FROM dbo.SMG_Schedules
    	     WHERE league_key = @league_key AND season_key = @season_key AND [week] = 'ncaa' AND event_status <> 'smg-not-played'
    	     GROUP BY CAST(start_date_time_EST AS DATE), level_id, level_name
        	 ORDER BY CAST(start_date_time_EST AS DATE) ASC

    		INSERT INTO @elimination ([date], level_id, selected)
	    	SELECT MAX([date]), level_id, MAX(ISNULL(selected, 0))
		      FROM @dates
    		 WHERE level_id IS NOT NULL
	    	 GROUP BY level_id

            DELETE d
              FROM @dates d
             INNER JOIN @elimination e
                ON e.level_id = d.level_id AND e.[date] <> d.[date]

            UPDATE @dates
	    	   SET scores_endpoint = '/Scores.svc/' + @leagueName + '/' + CAST(@season_key AS VARCHAR) + '/' + level_id
		     WHERE level_id IS NOT NULL
		END
		ELSE IF (@filter IN ('nit', 'cbi', 'cit'))
		BEGIN
    	    INSERT INTO @dates ([date])
        	SELECT CAST(start_date_time_EST AS DATE)
	          FROM dbo.SMG_Schedules
        	 WHERE league_key = @league_key AND season_key = @season_key AND [week] = @filter AND event_status <> 'smg-not-played'
	         GROUP BY CAST(start_date_time_EST AS DATE)
    	     ORDER BY CAST(start_date_time_EST AS DATE) ASC
		END
		ELSE
		BEGIN
		    IF (@filter = 'top25')
		    BEGIN
    	        INSERT INTO @dates ([date])
            	SELECT CAST(start_date_time_EST AS DATE)
	              FROM dbo.SMG_Schedules
            	 WHERE league_key = @league_key AND season_key = @season_key AND sub_season_type = 'season-regular' AND event_status <> 'smg-not-played'
	             GROUP BY CAST(start_date_time_EST AS DATE)
    	         ORDER BY CAST(start_date_time_EST AS DATE) ASC
		    END
		    ELSE
		    BEGIN
		        INSERT INTO @elimination (team_key)
		        SELECT t.team_key
		          FROM dbo.SMG_Teams t
		         INNER JOIN dbo.SMG_Leagues l
		            ON l.league_key = t.league_key AND l.season_key = t.season_key AND l.conference_key = t.conference_key AND SportsEditDB.dbo.SMG_fnSlugifyName(l.conference_display) = @filter
		         WHERE t.league_key = @league_key AND t.season_key = @season_key

        	    INSERT INTO @dates ([date])
            	SELECT CAST(ss.start_date_time_EST AS DATE)
	              FROM dbo.SMG_Schedules ss
	             INNER JOIN @elimination e
	                ON e.team_key IN (ss.away_team_key, ss.home_team_key)	          
            	 WHERE ss.league_key = @league_key AND ss.season_key = @season_key AND ss.sub_season_type = 'season-regular' AND ss.event_status <> 'smg-not-played'
	             GROUP BY CAST(ss.start_date_time_EST AS DATE)
    	         ORDER BY CAST(ss.start_date_time_EST AS DATE) ASC
		    END
		END
	END	
	ELSE IF (@leagueName = 'ncaaf')
	BEGIN
	    INSERT INTO @dates ([date])
    	SELECT CAST(start_date_time_EST AS DATE)
	      FROM dbo.SMG_Schedules
    	 WHERE league_key = @league_key AND season_key = @season_key AND level_id = @filter AND event_status <> 'smg-not-played'
	     GROUP BY CAST(start_date_time_EST AS DATE)
    	 ORDER BY CAST(start_date_time_EST AS DATE) ASC
	END
	ELSE
	BEGIN
	    INSERT INTO @dates ([date])
    	SELECT CAST(start_date_time_EST AS DATE)
	      FROM dbo.SMG_Schedules
    	 WHERE league_key = @league_key AND season_key = @season_key AND event_status <> 'smg-not-played'
	     GROUP BY CAST(start_date_time_EST AS DATE)
    	 ORDER BY CAST(start_date_time_EST AS DATE) ASC
	END

    IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw'))
    BEGIN     
        UPDATE @dates
           SET display = LEFT(DATENAME(WEEKDAY, [date]), 3) + ', ' + LEFT(DATENAME(MONTH, [date]), 3) + ' ' + CAST(DAY([date]) AS VARCHAR),
               scores_endpoint = '/Scores.svc/' + @leagueName + '/' + REPLACE(CAST([date] AS VARCHAR), '-', '/') + '/' + @filter
         WHERE scores_endpoint IS NULL
    END
    ELSE
    BEGIN
        UPDATE @dates
           SET display = LEFT(DATENAME(WEEKDAY, [date]), 3) + ', ' + LEFT(DATENAME(MONTH, [date]), 3) + ' ' + CAST(DAY([date]) AS VARCHAR),
               scores_endpoint = '/Scores.svc/' + @leagueName + '/' + REPLACE(CAST([date] AS VARCHAR), '-', '/')
         WHERE scores_endpoint IS NULL
    END

	UPDATE @dates
	   SET selected = '1'
	 WHERE [date] = @default_date

	IF NOT EXISTS (SELECT 1 FROM @dates WHERE selected = '1')
	BEGIN
		DECLARE @finals DATE
		DECLARE @upcoming DATE
		
		SELECT TOP 1 @finals = [date]
		  FROM @dates
		 ORDER BY [date] DESC

		SELECT TOP 1 @upcoming = [date]
		  FROM @dates
		 WHERE [date] > GETDATE()
		 ORDER BY [date] ASC

		IF (@finals < GETDATE())
		BEGIN
			UPDATE @dates
			   SET selected = '1'
			 WHERE [date] = @finals
		END
		ELSE
		BEGIN
			UPDATE @dates
			   SET selected = '1'
			 WHERE [date] = @upcoming
		END
	END

    UPDATE @dates
       SET display = 'Today'
     WHERE [date] = @today AND level_id IS NULL

    UPDATE @dates
       SET selected = '0'
     WHERE selected IS NULL OR selected <> '1'

/* END FULL SEASON SCHEDULE */
     

    -- button
    IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw'))
    BEGIN
        IF (@filter IN ('top25', 'bowls', 'playoffs', 'tourney', 'ncaa', 'nit', 'cbi', 'cit'))
        BEGIN
            SET @button_display = 'Rankings'
            SET @button_endpoint = '/Rankings.svc/' + @leagueName
        END
        ELSE
        BEGIN
            SET @button_endpoint = @button_endpoint + '/' + @filter
        END
    END


    -- filter selection
    DECLARE @filters TABLE (
        display VARCHAR(100),
        [key] VARCHAR(100)
    )
	INSERT INTO @filters (display, [key])
	VALUES ('Playoffs', 'playoffs'), ('Bowls', 'bowls'), ('Top 25', 'top25'), ('All Tourney', 'tourney'),
	       ('NCAA', 'ncaa'), ('NIT', 'nit'), ('CBI', 'cbi'), ('CIT', 'cit')

	
	IF (@filter IN (SELECT [key] FROM @filters))
	BEGIN
		SELECT @ribbon = display
		  FROM @filters
		 WHERE [key] = @filter
	END
	ELSE IF (@leagueName IN ('mls', 'epl', 'champions'))
	BEGIN
		SET @ribbon = (CASE WHEN @leagueName = 'champions' THEN 'Champions League' ELSE UPPER(@leagueName) END)
	END
	ELSE
	BEGIN
		SELECT @ribbon = conference_display
		  FROM dbo.SMG_Leagues
		 WHERE conference_key = @filter
	END



    ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
	SELECT (
               SELECT @ribbon AS ribbon,
                      (
                          SELECT 'true' AS 'json:Array',
                                 display, scores_endpoint, selected
                            FROM @dates
                           ORDER BY [date] ASC
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
