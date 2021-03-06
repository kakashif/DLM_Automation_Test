USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetStandingsMini_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[DES_GetStandingsMini_XML]
    @leagueName VARCHAR(100)
AS
-- =============================================
-- Author:		ikenticus
-- Create date: 05/21/2015
-- Description: get mini standings, based on SMG_GetStandingsMini_XML
-- Update:		06/09/2015 - ikenticus - adding team_link for team fronts
--              07/22/2015 - John Lin - STATS migration
--              08/31/2015 - John Lin - SDI migration
--              09/03/2015 - ikenticus - order by conference_order
--              10/06/2015 - John Lin - WNBA
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @season_key INT
    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
         
    SELECT @season_key = season_key
      FROM dbo.SMG_Default_Dates
     WHERE league_key = @leagueName AND page = 'standings'

    DECLARE @standings TABLE
    (
        conference_key VARCHAR(100),
		conference_name VARCHAR(100), 
        conference_order INT,
        division_key VARCHAR(100),
		division_name VARCHAR(100), 
        division_order INT,
        team_key VARCHAR(100),
        team_link VARCHAR(100),
        team_slug VARCHAR(100),
        team_abbreviation VARCHAR(100),
        wins INT DEFAULT 0,
        losses INT DEFAULT 0,
        ties INT DEFAULT 0, -- NFL
        winning_percentage VARCHAR(100), -- MLB, NBA, NFL, WNBA
        games_back VARCHAR(100), -- MLB, NBA, WNBA
        overtime_losses INT DEFAULT 0, -- NHL
        standings_points INT DEFAULT 0 -- NHL
    )
    IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw'))
    BEGIN
    	INSERT INTO @standings (conference_key, conference_name, conference_order, division_key, division_name, division_order, team_key, team_abbreviation, team_slug)
	    SELECT sl.conference_key, sl.conference_display, sl.conference_order, sl.division_key, sl.division_display, sl.division_order, st.team_key, st.team_abbreviation, st.team_slug
	      FROM dbo.SMG_Leagues sl
	     INNER JOIN dbo.SMG_Teams st
            ON st.league_key = sl.league_key AND st.season_key = sl.season_key AND
               st.conference_key = sl.conference_key AND ISNULL(st.division_key, '') = ISNULL(sl.division_key, '')
	     WHERE sl.league_key = @league_key AND sl.season_key = @season_key AND sl.tier = 1
    END
    ELSE
    BEGIN
    	INSERT INTO @standings (conference_key, conference_name, conference_order, division_key, division_name, division_order, team_key, team_abbreviation, team_slug)
	    SELECT sl.conference_key, sl.conference_display, sl.conference_order, sl.division_key, sl.division_display, sl.division_order, st.team_key, st.team_abbreviation, st.team_slug
	      FROM dbo.SMG_Leagues sl
	     INNER JOIN dbo.SMG_Teams st
            ON st.league_key = sl.league_key AND st.season_key = sl.season_key AND
               st.conference_key = sl.conference_key AND ISNULL(st.division_key, '') = ISNULL(sl.division_key, '')
	     WHERE sl.league_key = @league_key AND sl.season_key = @season_key
    END
  
    UPDATE s
       SET s.wins = CAST(ss.value AS INT)
      FROM @standings s
     INNER JOIN SportsEditDB.dbo.SMG_Standings ss
        ON ss.league_key = @league_key AND ss.season_key = @season_key AND ss.team_key = s.team_key AND ss.[column] = 'wins'

    UPDATE s
       SET s.losses = CAST(ss.value AS INT)
      FROM @standings s
     INNER JOIN SportsEditDB.dbo.SMG_Standings ss
        ON ss.league_key = @league_key AND ss.season_key = @season_key AND ss.team_key = s.team_key AND ss.[column] = 'losses'

    IF (@leagueName IN ('nfl', 'mls', 'natl', 'wwc', 'epl', 'champions'))
    BEGIN
        UPDATE s
           SET s.ties = CAST(ss.value AS INT)
          FROM @standings s
         INNER JOIN SportsEditDB.dbo.SMG_Standings ss
            ON ss.league_key = @league_key AND ss.season_key = @season_key AND ss.team_key = s.team_key AND ss.[column] = 'ties'
    END

    IF (@leagueName = 'mls')
    BEGIN
        UPDATE s
           SET s.standings_points = CAST(ss.value AS INT)
          FROM @standings s
         INNER JOIN SportsEditDB.dbo.SMG_Standings ss
            ON ss.league_key = @league_key AND ss.season_key = @season_key AND ss.team_key = s.team_key AND ss.[column] = 'points'
    END

    IF (@leagueName = 'nhl')
    BEGIN
        UPDATE s
           SET s.overtime_losses = CAST(ss.value AS INT)
          FROM @standings s
         INNER JOIN SportsEditDB.dbo.SMG_Standings ss
            ON ss.league_key = @league_key AND ss.season_key = @season_key AND ss.team_key = s.team_key AND ss.[column] = 'overtime-losses'

        UPDATE @standings
           SET standings_points = ((wins * 2) + overtime_losses)
    END

    IF (@leagueName IN ('natl', 'wwc', 'epl', 'champions'))
    BEGIN
        UPDATE s
           SET s.standings_points = CAST(ss.value AS INT)
          FROM @standings s
         INNER JOIN SportsEditDB.dbo.SMG_Standings ss
            ON ss.league_key = @league_key AND ss.season_key = @season_key AND ss.team_key = s.team_key AND ss.[column] = 'standing-points'
    END

    IF (@leagueName IN ('mlb', 'nba', 'nfl', 'wnba'))
    BEGIN
        UPDATE @standings
           SET winning_percentage = CASE
                                        WHEN wins + losses + ties = 0 THEN '.000'
                                        WHEN wins + losses + ties = wins THEN '1.00'
                                        ELSE CAST((CAST(wins + (ties * 0.5) AS FLOAT) / (wins + losses + ties)) AS DECIMAL(4, 3))
                                    END
    END

    DECLARE @leaders TABLE
    (
        conference_key VARCHAR(100),
        division_key VARCHAR(100),
        team_key VARCHAR(100),
        wins INT,
        losses INT
    )
    DECLARE @leader_wins INT
    DECLARE @leader_losses INT
    
    IF (@leagueName IN ('mlb', 'nba'))
    BEGIN
        INSERT INTO @leaders (conference_key, division_key)
        SELECT conference_key, division_key
          FROM @standings
         GROUP BY conference_key, division_key
        
        UPDATE l
           SET l.team_key = (SELECT TOP 1 s.team_key
                               FROM @standings s
                              WHERE s.conference_key = l.conference_key aND s.division_key = l.division_key
                              ORDER BY CAST(s.winning_percentage AS FLOAT) DESC)
          FROM @leaders l

        UPDATE l
           SET l.wins = s.wins, l.losses = s.losses
          FROM @leaders l
         INNER JOIN @standings s
            ON s.conference_key = l.conference_key AND s.division_key = l.division_key AND s.team_key = l.team_key

        UPDATE s
           SET s.games_back = CAST((CAST((l.wins - s.wins) - (l.losses - s.losses) AS FLOAT) / 2.0) AS DECIMAL(6, 1))
          FROM @standings s
         INNER JOIN @leaders l
            ON l.conference_key = s.conference_key AND l.division_key = s.division_key

        UPDATE @standings
           SET games_back = REPLACE(games_back, '.0', '')
    END

    IF (@leagueName = 'wnba')
    BEGIN

        INSERT INTO @leaders (conference_key)
        SELECT conference_key
          FROM @standings
         GROUP BY conference_key
        
        UPDATE l
           SET l.team_key = (SELECT TOP 1 s.team_key
                               FROM @standings s
                              WHERE s.conference_key = l.conference_key
                              ORDER BY CAST(s.winning_percentage AS FLOAT) DESC)
          FROM @leaders l

        UPDATE l
           SET l.wins = s.wins, l.losses = s.losses
          FROM @leaders l
         INNER JOIN @standings s
            ON s.conference_key = l.conference_key AND s.team_key = l.team_key

        UPDATE s
           SET s.games_back = CAST((CAST((l.wins - s.wins) - (l.losses - s.losses) AS FLOAT) / 2.0) AS DECIMAL(6, 1))
          FROM @standings s
         INNER JOIN @leaders l
            ON l.conference_key = s.conference_key

        UPDATE @standings
           SET games_back = REPLACE(games_back, '.0', '')
    END    	

	-- Team Fronts link
    IF (@leagueName IN ('mlb', 'nba',  'ncaaf', 'nfl'))
    BEGIN
        UPDATE @standings
           SET team_link = '/sports/' + @leagueName + '/' + team_slug + '/'
    END


    IF (@leagueName IN ('mls', 'wnba'))
    BEGIN
        SELECT
    	(
            SELECT UPPER(@leagueName) AS conference_key,
                   (
                       SELECT conf_s.conference_key AS division_key, conf_s.conference_name AS division_name, 
                              (
                                  SELECT s.team_abbreviation AS abbr_name, s.team_key, s.team_slug, s.wins, s.losses, s.ties,
                                         s.winning_percentage,
                                         (CASE
                                             WHEN s.games_back = '0' THEN '-'
                                             ELSE s.games_back
                                         END) AS games_back,                                  
                                         s.standings_points
                                    FROM @standings s
                                   WHERE s.conference_key = conf_s.conference_key
                                   ORDER BY CAST(s.games_back AS FLOAT) ASC, standings_points DESC
                                     FOR XML RAW('team'), TYPE
                              )
                         FROM @standings conf_s
                        GROUP BY conf_s.conference_key, conf_s.conference_name, conf_s.conference_order
                        ORDER BY conf_s.conference_order ASC
                          FOR XML RAW('division'), TYPE
                   )
               FOR XML RAW('conference'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END
    ELSE
    BEGIN
        SELECT
    	(
            SELECT conf_s.conference_key,
                   (
                       SELECT division_key, division_name, 
                              (
                                  SELECT s.team_abbreviation AS abbr_name, s.team_key, s.team_slug, s.team_link, s.wins, s.losses, s.ties,
                                         s.winning_percentage,
                                         (CASE
                                             WHEN s.games_back = '0' THEN '-'
                                             ELSE s.games_back
                                         END) AS games_back,
                                         s.overtime_losses, s.standings_points                                
                                    FROM @standings s
                                   WHERE s.conference_key = conf_s.conference_key AND ISNULL(s.division_key, '') = ISNULL(div_s.division_key, '')
                                   ORDER BY CAST(s.games_back AS FLOAT) ASC, CAST(s.winning_percentage AS FLOAT) DESC, standings_points DESC
                                     FOR XML RAW('team'), TYPE
                              )
                         FROM @standings div_s
                        WHERE div_s.conference_key = conf_s.conference_key
                        GROUP BY div_s.division_key, div_s.division_order, div_s.division_name
                        ORDER BY div_s.division_order ASC
                          FOR XML RAW('division'), TYPE
                   )
              FROM @standings conf_s
             GROUP BY conf_s.conference_key, conf_s.conference_order
             ORDER BY conf_s.conference_order ASC
               FOR XML RAW('conference'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END

    SET NOCOUNT OFF
END 

GO
