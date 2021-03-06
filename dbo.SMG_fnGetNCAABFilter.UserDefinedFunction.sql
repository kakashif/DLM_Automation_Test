USE [SportsDB]
GO
/****** Object:  UserDefinedFunction [dbo].[SMG_fnGetNCAABFilter]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE FUNCTION [dbo].[SMG_fnGetNCAABFilter] (
    @leagueKey VARCHAR(100),
    @startDate DATETIME,
    @filter    VARCHAR(100),
    @page      VARCHAR(100)
)
RETURNS @filters TABLE (
    id VARCHAR(100),
    display VARCHAR(100)
)
AS
-- =============================================
-- Author:		John Lin
-- Create date: 04/02/2014
-- Description:	get ncaab and ncaaw filter
-- Update:      03/10/2015 - John Lin - deprecate SMG_NCAA table
--				07/01/2015 - ikenticus - using converted SMG_Polls*
-- =============================================
BEGIN
    DECLARE @end_date DATETIME = DATEADD(SECOND, -1, DATEADD(DAY, 1, @startDate))
	    
    IF (@page = 'schedules')
    BEGIN
        SET @end_date = DATEADD(SECOND, -1, DATEADD(WEEK, 1, @startDate))
    END
	    
    DECLARE @events TABLE
    (
        season_key INT,
        away_key   VARCHAR(100),
        away_abbr  VARCHAR(100),
        away_rank  VARCHAR(100),
        away_conf  VARCHAR(100),
        home_key   VARCHAR(100),
        home_abbr  VARCHAR(100),
        home_rank  VARCHAR(100),
        home_conf  VARCHAR(100),
        [week]     VARCHAR(100)
    )
    DECLARE @all_filters TABLE (
        conference_key VARCHAR(100),
        conference_display VARCHAR(100)
    )
    
    INSERT INTO @events (season_key, away_key, home_key, [week])
    SELECT season_key, away_team_key, home_team_key, [week]
      FROM dbo.SMG_Schedules
     WHERE league_key = @leagueKey AND start_date_time_EST BETWEEN @startDate AND @end_date

	UPDATE e
	   SET away_abbr = t.team_abbreviation
	  FROM @events AS e
	 INNER JOIN dbo.SMG_Teams AS t ON t.team_key = e.away_key AND t.season_key = e.season_key
	 WHERE t.league_key = @leagueKey

	UPDATE e
	   SET home_abbr = t.team_abbreviation
	  FROM @events AS e
	 INNER JOIN dbo.SMG_Teams AS t ON t.team_key = e.home_key AND t.season_key = e.season_key
	 WHERE t.league_key = @leagueKey

    -- assume no poll
    DECLARE @league_name VARCHAR(100)
    DECLARE @season_key INT
    DECLARE @max_week INT

	SELECT TOP 1 @league_name = value_to
	  FROM SportsDB.dbo.SMG_Mappings
	 WHERE value_from = @leagueKey

    SELECT TOP 1 @season_key = season_key
      FROM @events
     ORDER BY season_key DESC

    SELECT TOP 1 @max_week = [week]
      FROM SportsEditDB.dbo.SMG_Polls
     WHERE league_key = @league_name AND season_key = @season_key AND fixture_key = 'smg-usat'
     ORDER BY [week] DESC
        
    -- set to max week
    UPDATE e
       SET e.away_rank = sp.ranking
      FROM @events e
     INNER JOIN SportsEditDB.dbo.SMG_Polls sp
        ON sp.league_key = @league_name AND sp.season_key = @season_key AND sp.fixture_key = 'smg-usat' AND
           sp.team_key = e.away_abbr AND e.[week] NOT IN ('ncaa', 'nit', 'cbi', 'cit', 'wnit', 'wbi') AND sp.[week] = @max_week
               
    UPDATE e
       SET e.home_rank = sp.ranking
      FROM @events e
     INNER JOIN SportsEditDB.dbo.SMG_Polls sp
        ON sp.league_key = @league_name AND sp.season_key = @season_key AND sp.fixture_key = 'smg-usat' AND
           sp.team_key = e.home_abbr AND e.[week] NOT IN ('ncaa', 'nit', 'cbi', 'cit', 'wnit', 'wbi') AND sp.[week] = @max_week

    -- set to correct week 
    UPDATE e
       SET e.away_rank = sp.ranking
      FROM @events e
     INNER JOIN SportsEditDB.dbo.SMG_Polls sp
        ON sp.league_key = @league_name AND sp.season_key = @season_key AND sp.fixture_key = 'smg-usat' AND
           sp.team_key = e.away_abbr AND e.[week] NOT IN ('ncaa', 'nit', 'cbi', 'cit', 'wnit', 'wbi') AND sp.[week] =  CAST(e.[week] AS INT)
               
    UPDATE e
       SET e.home_rank = sp.ranking
      FROM @events e
     INNER JOIN SportsEditDB.dbo.SMG_Polls sp
        ON sp.league_key = @league_name AND sp.season_key = @season_key AND sp.fixture_key = 'smg-usat' AND
           sp.team_key = e.home_abbr AND e.[week] NOT IN ('ncaa', 'nit', 'cbi', 'cit', 'wnit', 'wbi') AND sp.[week] =  CAST(e.[week] AS INT)

    -- ncaa
    UPDATE e
       SET e.away_rank = CAST(enbt.seed AS VARCHAR)
      FROM @events e
     INNER JOIN SportsEditDB.dbo.Edit_NCAA_Bracket_Teams enbt
        ON enbt.league_key = @leagueKey AND enbt.season_key = @season_key AND enbt.team_key = e.away_key
     WHERE e.[week] = 'ncaa'
               
    UPDATE e
       SET e.home_rank = CAST(enbt.seed AS VARCHAR)
      FROM @events e
     INNER JOIN SportsEditDB.dbo.Edit_NCAA_Bracket_Teams enbt
        ON enbt.league_key = @leagueKey AND enbt.season_key = @season_key AND enbt.team_key = e.home_key
     WHERE e.[week] = 'ncaa'
    

    IF EXISTS (SELECT 1 FROM @events WHERE [week] NOT IN ('ncaa', 'nit', 'cbi', 'cit', 'wnit', 'wbi'))
    BEGIN
        INSERT INTO @filters (id, display)
        VALUES ('div1', 'All Div I')
            
        IF EXISTS (SELECT 1 FROM @events WHERE CAST(ISNULL(away_rank, '') AS INT) + CAST(ISNULL(home_rank, '') AS INT) > 0)
        BEGIN
            INSERT INTO @filters (id, display)
            VALUES ('top25', 'Top 25')
        END
    END
        
    IF EXISTS (SELECT 1 FROM @events WHERE [week] IN ('ncaa', 'nit', 'cbi', 'cit', 'wnit', 'wbi'))
    BEGIN
        INSERT INTO @filters (id, display)
        VALUES ('tourney', 'All Tourney')
                    
        INSERT INTO @filters (id, display)
        SELECT LOWER([week]), UPPER([week])
          FROM @events
         WHERE [week] IS NOT NULL
         GROUP BY [week]
         ORDER BY (CASE
                     WHEN [week] = 'ncaa' THEN 1
                     WHEN CHARINDEX('nit', [week]) > 0 THEN 2
                     WHEN CHARINDEX('bi', [week]) > 0 THEN 2
                     WHEN [week] = 'cit' THEN 3
                     ELSE 4
                  END)
    END
        
    IF EXISTS (SELECT 1 FROM @events WHERE [week] NOT IN ('ncaa', 'nit', 'cbi', 'cit', 'wnit', 'wbi'))
    BEGIN
        UPDATE e
           SET e.away_conf = st.conference_key
          FROM @events e
         INNER JOIN dbo.SMG_Teams st
            ON st.league_key = @leagueKey AND st.season_key = @season_key AND st.team_key = e.away_key

        UPDATE e
           SET e.home_conf = st.conference_key
          FROM @events e
         INNER JOIN dbo.SMG_Teams st
            ON st.league_key = @leagueKey AND st.season_key = @season_key AND st.team_key = e.home_key

        INSERT INTO @filters (id, display)
        SELECT SportsEditDB.dbo.SMG_fnSlugifyName(sl.conference_display), sl.conference_display
          FROM dbo.SMG_Leagues sl
         INNER JOIN @events e
            ON sl.conference_key IN (e.away_conf, e.home_conf)
         WHERE sl.league_key = @leagueKey AND sl.season_key = @season_key AND sl.conference_key IS NOT NULL
         GROUP BY sl.conference_key, sl.conference_display, sl.conference_order
         ORDER BY sl.conference_order ASC
	END
           
    RETURN
END

GO
