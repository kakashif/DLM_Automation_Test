USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetScheduleWeekly_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetScheduleWeekly_XML]
   @swipe VARCHAR(100),
   @leagueName VARCHAR(100),
   @seasonKey INT,
   @week VARCHAR(100),
   @subSeasonType VARCHAR(100) = NULL,
   @filter	VARCHAR(100) = NULL
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 06/12/2014
  -- Description: get week schedule for jameson
  -- Update:      06/25/2014 - John Lin - fix pre season logic
  --              08/20/2014 - ikenticus - adding hack to navigate to previous/next season for DEV testing
  --			  08/21/2014 - ikenticus - adding ribbon in schedule node to display filter
  --			  09/02/2014 - ikenticus - utilizing full season schedule per JIRA SJ-110
  --			  09/04/2014 - ikenticus - adding selected for first upcoming date when not this week
  --			  09/08/2014 - ikenticus - adding share_link
  --              09/16/2014 - ikenticus - adding euro soccer
  --              09/24/2014 - ikenticus - adding soccer ribbon
  --              09/29/2014 - John Lin - force sort by
  --              12/02/2014 - John Lin - ncaaf rounds
  --              12/12/2014 - John Lin - bowls and playoffs render ranking
  --              12/18/2014 - John Lin - add playoffs to ribbon
  --              12/19/2014 - John Lin - no filtering for top25
  --              01/29/2015 - John Lin - rename championship to conference
  --              04/14/2015 - ikenticus - altering week by rank+count for EPL to discard one-off event dates
  --              05/15/2015 - ikenticus - obtain league_key from SMG_fnGetLeagueKey
  --              05/18/2015 - ikenticus - updating week display logic for world cup
  --              07/15/2015 - ikenticus - week display should default to week if empty level name (EPL)
  --              08/18/2015 - John Lin - SDI migration
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    IF (@leagueName NOT IN ('ncaaf', 'nfl', 'epl', 'natl', 'wwc', 'premierleague', 'champions'))
    BEGIN
        RETURN
    END

    IF (@leagueName = 'ncaaf' AND @seasonKey = 0 AND @week = '0')
    BEGIN
        SELECT @seasonKey = season_key, @week = [week]
          FROM dbo.SMG_Default_Dates
         WHERE league_key = 'ncaaf' AND page = 'scores'
    END

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
	DECLARE @ribbon VARCHAR(100)
    DECLARE @button_display VARCHAR(100) = 'Standings'
    DECLARE @button_endpoint VARCHAR(100) = '/Standings.svc/' + @leagueName
    DECLARE @share_link VARCHAR(100) = 'http://www.usatoday.com/sports/' + @leagueName + '/standings/'
                 
	DECLARE @weeks TABLE
	(
        [week] VARCHAR(100),
        sub_season_type VARCHAR(100),
        [date]  DATE,
        display VARCHAR(100),
        scores_endpoint VARCHAR(100),
        selected VARCHAR(100),
		[rank] INT
	)
    DECLARE @elimination TABLE
    (
        [date]   DATE,
        level_id VARCHAR(100),
        selected INT,
        team_key VARCHAR(100)
    )

/* BEGIN FULL SEASON SCHEDULE */

    IF (@leagueName = 'ncaaf')
    BEGIN
	    IF (@filter IN ('bowls', 'playoffs'))
	    BEGIN
       	    INSERT INTO @weeks ([date])
        	SELECT CAST(start_date_time_EST AS DATE)
	          FROM dbo.SMG_Schedules
        	 WHERE league_key = @league_key AND season_key = @seasonKey AND level_id = @filter AND event_status <> 'smg-not-played'
	         GROUP BY CAST(start_date_time_EST AS DATE)
    	     ORDER BY CAST(start_date_time_EST AS DATE) ASC

	        UPDATE @weeks
	           SET display = LEFT(DATENAME(WEEKDAY, [date]), 3) + ', ' + LEFT(DATENAME(MONTH, [date]), 3) + ' ' + CAST(DAY([date]) AS VARCHAR),
                   scores_endpoint = '/Scores.svc/ncaaf/' + REPLACE(CAST([date] AS VARCHAR), '-', '/') + '/' + @filter
		END
		ELSE
		BEGIN
		    IF (@filter = 'top25')
		    BEGIN
        	    INSERT INTO @weeks ([week], [date])
            	SELECT [week], CAST(MIN(start_date_time_EST) AS DATE)
	              FROM dbo.SMG_Schedules
            	 WHERE league_key = @league_key AND season_key = @seasonKey AND event_status <> 'smg-not-played' AND [week] NOT IN ('bowls', 'playoffs')
	             GROUP BY [week]
    	         ORDER BY CAST([week] AS INT) ASC
		    END
		    ELSE
		    BEGIN
		        INSERT INTO @elimination (team_key)
		        SELECT t.team_key
		          FROM dbo.SMG_Teams t
		         INNER JOIN dbo.SMG_Leagues l
		            ON l.league_key = t.league_key AND l.season_key = t.season_key AND l.conference_key = t.conference_key AND SportsEditDB.dbo.SMG_fnSlugifyName(l.conference_display) = @filter
		         WHERE t.league_key = @league_key AND t.season_key = @seasonKey
		    
        	    INSERT INTO @weeks ([week], [date])
            	SELECT [week], CAST(MIN(ss.start_date_time_EST) AS DATE)
	              FROM dbo.SMG_Schedules ss
	             INNER JOIN @elimination e
	                ON e.team_key IN (ss.away_team_key, ss.home_team_key)	          
            	 WHERE ss.league_key = @league_key AND ss.season_key = @seasonKey AND ss.event_status <> 'smg-not-played' AND [week] NOT IN ('bowls', 'playoffs')
	             GROUP BY [week]
    	         ORDER BY CAST([week] AS INT) ASC
		    END

            UPDATE @weeks
               SET display = 'Week ' + [week],
                   scores_endpoint = '/Scores.svc/ncaaf/' + CAST(@seasonKey AS VARCHAR) + '/' + [week] + '/' + @filter
		END
    END
    ELSE
    BEGIN
		IF (@leagueName IN ('champions', 'natl', 'wwc', 'epl'))
		BEGIN
			INSERT INTO @weeks ([week], sub_season_type, [date], display, [rank])
			SELECT [week], sub_season_type, CAST(start_date_time_EST AS DATE), level_name,
				   RANK() OVER (PARTITION BY sub_season_type, [week] ORDER BY CAST(start_date_time_EST AS DATE) ASC)
			  FROM dbo.SMG_Schedules
			 WHERE league_key = @league_key AND season_key = @seasonKey AND event_status <> 'smg-not-played' AND [week] IS NOT NULL AND sub_season_type = 'season-regular'
			 GROUP BY [week], sub_season_type, CAST(start_date_time_EST AS DATE), level_name
			 ORDER BY CAST(start_date_time_EST AS DATE) ASC
		END
		ELSE
		BEGIN
			INSERT INTO @weeks ([week], sub_season_type, [date], display, [rank])
			SELECT [week], sub_season_type, CAST(start_date_time_EST AS DATE), level_name,
				   RANK() OVER (PARTITION BY sub_season_type, [week] ORDER BY CAST(start_date_time_EST AS DATE) ASC)
			  FROM dbo.SMG_Schedules
			 WHERE league_key = @league_key AND season_key = @seasonKey AND event_status <> 'smg-not-played' AND [week] IS NOT NULL
			 GROUP BY [week], sub_season_type, CAST(start_date_time_EST AS DATE), level_name
			 ORDER BY CAST(start_date_time_EST AS DATE) ASC
		END

        DELETE FROM @weeks WHERE [rank] > 1

        IF (@leagueName = 'nfl')
        BEGIN
            UPDATE @weeks
               SET scores_endpoint = '/Scores.svc/' + @leagueName + '/' + CAST(@seasonKey AS VARCHAR) + '/' + sub_season_type + '/' + [week]
        END
        ELSE
        BEGIN
            UPDATE @weeks
               SET scores_endpoint = '/Scores.svc/' + @leagueName + '/' + CAST(@seasonKey AS VARCHAR) + '/' + [week]
        END

        UPDATE @weeks
           SET display = CASE
		                     WHEN [week] = 'bowls' THEN 'Bowls'
		                     WHEN [week] = 'hall-of-fame' THEN 'Hall Of Fame'
		                     WHEN [week] = 'wild-card' THEN 'Wild Card'
		                     WHEN [week] = 'divisional' THEN 'Divisional'
		                     WHEN [week] = 'conference' THEN 'Conference'
    		                 WHEN [week] = 'pro-bowl' THEN 'Pro Bowl'
    		                 WHEN [week] = 'super-bowl' THEN 'Super Bowl'
                             WHEN [week] = 'group-stage' THEN 'Group Stage'
	    	                 ELSE (CASE
		                              WHEN @leagueName = 'nfl' AND sub_season_type = 'pre-season' THEN 'Pre Week ' + [week]
		                              WHEN @leagueName IN ('epl', 'champions', 'natl', 'wwc') AND display NOT IN ('Group Stage', 'Regular Season', '') THEN display							
		                              ELSE 'Week ' + [week]
		                          END)
    		             END
    END

    IF (@leagueName = 'nfl')
	BEGIN
		UPDATE @weeks
		   SET selected = '1'
		 WHERE sub_season_type = @subSeasonType AND [week] = @week
	END
	ELSE
	BEGIN
		UPDATE @weeks
		   SET selected = '1'
		 WHERE [week] = @week
	END

	IF NOT EXISTS (SELECT 1 FROM @weeks WHERE selected = '1')
	BEGIN
		DECLARE @finals DATE
		DECLARE @upcoming DATE
		
		SELECT TOP 1 @finals = [date]
		  FROM @weeks
		 ORDER BY [date] DESC

		SELECT TOP 1 @upcoming = [date]
		  FROM @weeks
		 WHERE [date] > GETDATE()
		 ORDER BY [date] ASC

		IF (@finals < GETDATE())
		BEGIN
			UPDATE @weeks
			   SET selected = '1'
			 WHERE [date] = @finals
		END
		ELSE
		BEGIN
			UPDATE @weeks
			   SET selected = '1'
			 WHERE [date] = @upcoming
		END
	END

    UPDATE @weeks
       SET selected = '0'
     WHERE selected IS NULL OR selected <> '1'

/* END FULL SEASON SCHEDULE */


    -- button
    IF (@leagueName = 'ncaaf')
    BEGIN
        IF (@filter IN ('top25', 'bowls', 'playoffs'))
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
	VALUES ('Playoffs', 'playoffs'), ('Bowls', 'bowls'), ('Top 25', 'top25')

	
	IF (@filter IN (SELECT [key] FROM @filters))
	BEGIN
		SELECT @ribbon = display
		  FROM @filters
		 WHERE [key] = @filter
	END
	ELSE IF (@leagueName IN ('mls', 'epl', 'champions', 'natl', 'wwc'))
	BEGIN
		SET @ribbon = (CASE
						WHEN @leagueName = 'champions' THEN 'Champions League'
						WHEN @leagueName = 'natl' THEN 'World Cup'
						WHEN @leagueName = 'wwc' THEN 'Women''s World Cup'
						ELSE UPPER(@leagueName) END)
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
                            FROM @weeks
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
