USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetNFLTrends_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[HUB_GetNFLTrends_XML]
	@dayOfWeek VARCHAR(100)
AS
--=============================================
-- Author: John Lin
-- Create date: 09/26/2014
-- Description: get info of Monday or Thursday game and its team info the following week
-- =============================================
BEGIN
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @dow INT = 5
    
    IF (@dayOfWeek = 'monday')
    BEGIN
        SET @dow = 2
    END

    DECLARE @trends TABLE
    (
	    [date] DATE,
	    season_key INT,
	    event_key VARCHAR(100),
	    away_key VARCHAR(100),
	    home_key VARCHAR(100),
	    away_score INT,
	    home_score INT,
	    away_name VARCHAR(100),
	    home_name VARCHAR(100),
	    away_event_key VARCHAR(100),
	    away_away_key VARCHAR(100),
	    away_home_key VARCHAR(100),
	    away_away_score INT,
	    away_home_score INT,
	    away_away_name VARCHAR(100),
	    away_home_name VARCHAR(100),
	    away_score_diff INT,
	    home_event_key VARCHAR(100),
	    home_away_key VARCHAR(100),
	    home_home_key VARCHAR(100),
	    home_score_diff INT,
	    home_away_score INT,
	    home_home_score INT,
	    home_away_name VARCHAR(100),
	    home_home_name VARCHAR(100)
	)
	
    INSERT INTO @trends ([date], season_key, event_key, away_key, home_key, away_score, home_score)
    SELECT CAST(start_date_time_EST AS DATE), season_key, event_key, away_team_key, home_team_key, away_team_score, home_team_score
      FROM dbo.SMG_Schedules
     WHERE league_key = 'l.nfl.com' AND sub_season_type = 'season-regular' AND season_key > '2010' AND [week] <> '16' AND
           start_date_time_EST < GETDATE() AND DATEPART(dw, start_date_time_EST) = @dow

    UPDATE t
       SET t.away_name = st.team_last
      FROM @trends t
     INNER JOIN dbo.SMG_Teams st
        ON st.season_key = t.season_key AND st.team_key = t.away_key
 
    UPDATE t
       SET t.home_name = st.team_last
      FROM @trends t
     INNER JOIN dbo.SMG_Teams st
        ON st.season_key = t.season_key AND st.team_key = t.home_key

    -- away team's next event
    UPDATE @trends
       SET away_event_key = (SELECT TOP 1 ss.event_key
                               FROM dbo.SMG_Schedules ss
                              WHERE ss.league_key = 'l.nfl.com' AND ss.sub_season_type = 'season-regular' AND
                                    ss.start_date_time_EST > DATEADD(DAY, 1, [date]) AND away_key IN (ss.away_team_key, ss.home_team_key)
                              ORDER BY ss.start_date_time_EST ASC)

    UPDATE t
       SET t.away_away_key = ss.away_team_key, t.away_home_key = ss.home_team_key,
           t.away_away_score = ss.away_team_score, t.away_home_score = ss.home_team_score
      FROM @trends t
     INNER JOIN dbo.SMG_Schedules ss
        ON ss.event_key = t.away_event_key

    UPDATE t
       SET t.away_away_name = st.team_last
      FROM @trends t
     INNER JOIN dbo.SMG_Teams st
        ON st.season_key = t.season_key AND st.team_key = t.away_away_key
 
    UPDATE t
       SET t.away_home_name = st.team_last
      FROM @trends t
     INNER JOIN dbo.SMG_Teams st
        ON st.season_key = t.season_key AND st.team_key = t.away_home_key

    -- score diff
    UPDATE @trends
       SET away_score_diff = away_away_score - away_home_score       
     WHERE away_key = away_away_key 

    UPDATE @trends
       SET away_score_diff = away_home_score - away_away_score       
     WHERE away_key = away_home_key 


    -- home team's next event
    UPDATE @trends
       SET home_event_key = (SELECT TOP 1 ss.event_key
                               FROM dbo.SMG_Schedules ss
                              WHERE ss.league_key = 'l.nfl.com' AND ss.sub_season_type = 'season-regular' AND
                                   ss.start_date_time_EST > DATEADD(DAY, 1, [date]) AND home_key IN (ss.away_team_key, ss.home_team_key)
                              ORDER BY ss.start_date_time_EST ASC)

    UPDATE t
       SET t.home_away_key = ss.away_team_key, t.home_home_key = ss.home_team_key,
           t.home_away_score = ss.away_team_score, t.home_home_score = ss.home_team_score
      FROM @trends t
     INNER JOIN dbo.SMG_Schedules ss
        ON ss.event_key = t.home_event_key

    UPDATE t
       SET t.home_away_name = st.team_last
      FROM @trends t
     INNER JOIN dbo.SMG_Teams st
        ON st.season_key = t.season_key AND st.team_key = t.home_away_key
 
    UPDATE t
       SET t.home_home_name = st.team_last
      FROM @trends t
     INNER JOIN dbo.SMG_Teams st
        ON st.season_key = t.season_key AND st.team_key = t.home_home_key

    -- score diff
    UPDATE @trends
       SET home_score_diff = home_away_score - home_home_score       
     WHERE home_key = home_away_key 

    UPDATE @trends
       SET home_score_diff = home_home_score - home_away_score       
     WHERE home_key = home_home_key 



    SELECT
	(
        SELECT [date], away_name, away_score, home_name, home_score,
               away_away_name, away_away_score, away_home_name, away_home_score, away_score_diff,
	           home_away_name, home_away_score, home_home_name, home_home_score, home_score_diff
          FROM @trends
         ORDER BY [date] ASC
           FOR XML RAW('trend'), TYPE
    )
    FOR XML PATH(''), ROOT('root')

END


GO
