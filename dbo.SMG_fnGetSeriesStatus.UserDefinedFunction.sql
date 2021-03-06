USE [SportsDB]
GO
/****** Object:  UserDefinedFunction [dbo].[SMG_fnGetSeriesStatus]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[SMG_fnGetSeriesStatus] 
(
    @leagueKey        VARCHAR(100),
    @seasonKey        INT,
    @awayTeamKey      VARCHAR(100),	
    @homeTeamKey      VARCHAR(100),
    @startDateTimeEST DATETIME	
)
RETURNS @series_status TABLE
(
    [round] INT,
	game INT,
	away_team_abbr VARCHAR(100),
	home_team_abbr VARCHAR(100),
	away_conference_key VARCHAR(100),
	home_conference_key VARCHAR(100),
	away_team_wins INT,
	home_team_wins INT,
	away_team_scores INT,
	home_team_scores INT
)
AS
-- =============================================
-- Author:		John Lin
-- Create date: 01/15/2014
-- Description:	return status of series from event
-- Update: 04/22/2014 - John Lin - fix team count bug
--         10/17/2014 - John Lin - refactor some stuff
--         11/11/2014 - John Lin - fix bad logic
--         04/14/2014 - John Lin - set null to 0 for wins and scores
--         04/17/2014 - John Lin - set null to 0 for wins and scores before usage
--         04/27/2015 - John Lin - remove event status check
--         10/12/2015 - John Lin - check post event
-- =============================================
BEGIN
    DECLARE @round INT
    DECLARE	@game INT
    DECLARE @away_team_count INT
    DECLARE @home_team_count INT
	
	DECLARE @away_team_wins INT
	DECLARE @home_team_wins INT
	DECLARE @away_team_away_wins INT
	DECLARE @away_team_home_wins INT
	DECLARE @home_team_away_wins INT
	DECLARE @home_team_home_wins INT
	
	DECLARE @away_team_scores INT
	DECLARE @home_team_scores INT
	DECLARE @away_team_away_scores INT
	DECLARE @away_team_home_scores INT
	DECLARE @home_team_away_scores INT
	DECLARE @home_team_home_scores INT

	DECLARE @away_team_abbr VARCHAR(100)
	DECLARE @home_team_abbr VARCHAR(100)
	DECLARE @away_conference_key VARCHAR(100)
	DECLARE @home_conference_key VARCHAR(100)

    SELECT @away_team_count = COUNT(*)
      FROM (SELECT away_team_key
              FROM dbo.SMG_Schedules WITH (NOLOCK)
             WHERE league_key = @leagueKey AND season_key = @seasonKey AND sub_season_type = 'post-season' AND 
                   home_team_key = @homeTeamKey AND start_date_time_EST <= @startDateTimeEST
             GROUP BY away_team_key) AS away_teams
     
    SELECT @home_team_count = COUNT(*)
      FROM (SELECT home_team_key
              FROM dbo.SMG_Schedules WITH (NOLOCK)
             WHERE league_key = @leagueKey AND season_key = @seasonKey AND sub_season_type = 'post-season' AND 
                   away_team_key = @awayTeamKey AND start_date_time_EST <= @startDateTimeEST
             GROUP BY home_team_key) AS home_teams
            
    SET @round = ((@away_team_count + @home_team_count) / 2)            

	DECLARE @series TABLE 
	(
	    event_key VARCHAR(100),
	    away_team_key VARCHAR(100),
	    home_team_key VARCHAR(100),
	    away_team_win INT,
	    home_team_win INT,
	    away_team_score INT,
	    home_team_score INT,
	    event_status VARCHAR(100),
	    start_date_time_EST DATETIME
	)

    INSERT INTO @series (event_key, away_team_key, home_team_key, away_team_score, home_team_score, event_status, start_date_time_EST)
    SELECT event_key, away_team_key, home_team_key, away_team_score, home_team_score, event_status, start_date_time_EST
      FROM dbo.SMG_Schedules WITH (NOLOCK)
     WHERE league_key = @leagueKey AND season_key = @seasonKey AND sub_season_type = 'post-season' AND
           away_team_key IN (@awayTeamKey, @homeTeamKey) AND home_team_key IN (@awayTeamKey, @homeTeamKey) AND
           start_date_time_EST <= @startDateTimeEST

    UPDATE @series
       SET away_team_win = 1, home_team_win = 0
     WHERE away_team_score > home_team_score AND event_status = 'post-event'
       
    UPDATE @series
       SET home_team_win = 1, away_team_win = 0
     WHERE home_team_score > away_team_score AND event_status = 'post-event'
    
    SELECT @game = COUNT(*)
      FROM @series

    -- wins
    SELECT @away_team_away_wins = ISNULL(SUM(away_team_win), 0)
      FROM @series
     WHERE away_team_key = @awayTeamKey

    SELECT @away_team_home_wins = ISNULL(SUM(home_team_win), 0)
      FROM @series
     WHERE home_team_key = @awayTeamKey

    SELECT @home_team_away_wins = ISNULL(SUM(away_team_win), 0)
      FROM @series
     WHERE away_team_key = @homeTeamKey

    SELECT @home_team_home_wins = ISNULL(SUM(home_team_win), 0)
      FROM @series
     WHERE home_team_key = @homeTeamKey

    UPDATE @series
       SET @away_team_wins = @away_team_away_wins + @away_team_home_wins,
           @home_team_wins = @home_team_away_wins + @home_team_home_wins

    -- scores
    SELECT @away_team_away_scores = ISNULL(SUM(away_team_score), 0)
      FROM @series
     WHERE away_team_key = @awayTeamKey

    SELECT @away_team_home_scores = ISNULL(SUM(home_team_score), 0)
      FROM @series
     WHERE home_team_key = @awayTeamKey

    SELECT @home_team_away_scores = ISNULL(SUM(away_team_score), 0)
      FROM @series
     WHERE away_team_key = @homeTeamKey

    SELECT @home_team_home_scores = ISNULL(SUM(home_team_score), 0)
      FROM @series
     WHERE home_team_key = @homeTeamKey

    UPDATE @series
       SET @away_team_scores = @away_team_away_scores + @away_team_home_scores,
           @home_team_scores = @home_team_away_scores + @home_team_home_scores

    -- abbreviation, conference
    SELECT @away_team_abbr = team_abbreviation, @home_conference_key = conference_key
      FROM dbo.SMG_Teams WITH (NOLOCK)
     WHERE league_key = @leagueKey AND season_key = @seasonKey AND team_key = @awayTeamKey
	
    SELECT @home_team_abbr = team_abbreviation, @away_conference_key = conference_key
      FROM dbo.SMG_Teams WITH (NOLOCK)
     WHERE league_key = @leagueKey AND season_key = @seasonKey AND team_key = @homeTeamKey

    INSERT INTO @series_status ([round], game, away_team_abbr, home_team_abbr, away_conference_key, home_conference_key,
	                            away_team_wins, home_team_wins, away_team_scores, home_team_scores)
	SELECT @round, @game, @away_team_abbr, @home_team_abbr, @away_conference_key, @home_conference_key,
	       @away_team_wins, @home_team_wins, @away_team_scores, @home_team_scores
	
	RETURN
END

GO
