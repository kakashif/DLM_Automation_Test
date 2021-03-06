USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[AZC_Score_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[AZC_Score_XML]
   @leagueName VARCHAR(100),
   @teamSlug VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 09/24/2015
  -- Description: get pre, mid and post score for given team
  -- Update:      10/07/2015 - ikenticus: fixing UTC conversion
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    IF (@leagueName NOT IN ('mlb', 'nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba',
                            'mls', 'wwc'))
    BEGIN
        SELECT 'invalid league name' AS [message], '400' AS [status]
           FOR XML PATH(''), ROOT('root')

        RETURN
    END

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @now DATETIME = GETDATE()
   	DECLARE @season_key INT
    DECLARE @team_key VARCHAR(100)

    SELECT @season_key = team_season_key
      FROM dbo.SMG_Default_Dates
     WHERE league_key = @leagueName AND page = 'schedules'

    SELECT @team_key = team_key
      FROM dbo.SMG_Teams
     WHERE league_key = @league_key AND season_key = @season_key AND team_slug = @teamSlug

	DECLARE @events TABLE
	(
	    event_id INT,
	    event_status VARCHAR(100),
	    game_status VARCHAR(100),
	    start_date_time_EST DATETIME,
	    start_date_time_UTC VARCHAR(100),
	    away_abbr VARCHAR(100),
	    away_score INT,
	    home_abbr VARCHAR(100),
	    home_score INT,
	    -- extra
	    event_key VARCHAR(100),
	    away_team_key VARCHAR(100),
	    home_team_key VARCHAR(100)
	)
    INSERT INTO @events (event_key, event_status, game_status, start_date_time_EST, away_team_key, away_score, home_team_key, home_score)
    SELECT TOP 1 event_key, event_status, game_status, start_date_time_EST, away_team_key, away_team_score, home_team_key, home_team_score
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @season_key AND @team_key IN (away_team_key, home_team_key) AND
           event_status NOT IN ('smg-not-played', 'pre-event', 'mid-event') AND start_date_time_EST < @now
     ORDER BY start_date_time_EST DESC

    INSERT INTO @events (event_key, event_status, game_status, start_date_time_EST, away_team_key, away_score, home_team_key, home_score)
    SELECT TOP 1 event_key, event_status, game_status, start_date_time_EST, away_team_key, away_team_score, home_team_key, home_team_score
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @season_key AND @team_key IN (away_team_key, home_team_key) AND
           event_status = 'pre-event' AND start_date_time_EST > @now
     ORDER BY start_date_time_EST ASC

    INSERT INTO @events (event_key, event_status, game_status, start_date_time_EST, away_team_key, away_score, home_team_key, home_score)
    SELECT TOP 1 event_key, event_status, game_status, start_date_time_EST, away_team_key, away_team_score, home_team_key, home_team_score
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @season_key AND @team_key IN (away_team_key, home_team_key) AND
           event_status = 'mid-event'
     ORDER BY start_date_time_EST DESC

    UPDATE e
       SET e.away_abbr = st.team_abbreviation
      FROM @events e
     INNER JOIN dbo.SMG_Teams st
        ON st.league_key = @league_key AND st.season_key = @season_key AND st.team_key = e.away_team_key

    UPDATE e
       SET e.home_abbr = st.team_abbreviation
      FROM @events e
     INNER JOIN dbo.SMG_Teams st
        ON st.league_key = @league_key AND st.season_key = @season_key AND st.team_key = e.home_team_key

    UPDATE @events
       SET event_id = CAST(dbo.SMG_fnEventId(event_key) AS INT),
           start_date_time_UTC = REPLACE(LEFT(CONVERT(VARCHAR, DATEADD(HOUR, DATEDIFF(HOUR, GETDATE(), GETUTCDATE()), start_date_time_EST), 120), 19), ' ', 'T') + '+00:00'




    SELECT
	(
        SELECT event_id, event_status, game_status, start_date_time_EST, start_date_time_UTC, away_abbr, away_score, home_abbr, home_score
          FROM @events
         ORDER BY start_date_time_EST DESC
           FOR XML RAW('events'), TYPE
    )
    FOR XML PATH(''), ROOT('root')

	
END

GO
