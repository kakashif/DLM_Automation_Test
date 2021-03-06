USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[MOB_GetTeamStandings_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[MOB_GetTeamStandings_XML]
   @leagueName VARCHAR(100),
   @teamSlug VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 01/28/2015
  -- Description: get team leaders for mobile
  -- Update: 03/16/2015 - John Lin - fix typo
  --         05/18/2015 - John Lin - return error
  --         05/20/2015 - John Lin - add Women's World Cup
  --         06/23/2015 - John Lin - STATS migration
  --         10/12/2015 - John Lin - SDI migration
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
    DECLARE @season_key INT
    DECLARE @conference_key VARCHAR(100)
    DECLARE @division_key VARCHAR(100)
    DECLARE @logo_prefix VARCHAR(100) = 'http://www.gannett-cdn.com/media/SMG/sports_logos/'
    DECLARE @logo_folder VARCHAR(100) = '-whitebg/22/'
    DECLARE @flag_folder VARCHAR(100) = 'countries/flags/22/'
    DECLARE @logo_suffix VARCHAR(100) = '.png'    

    SELECT TOP 1 @season_key = season_key
      FROM SportsEditDB.dbo.SMG_Standings
     WHERE league_key = @leagueName
     ORDER BY season_key DESC

    SELECT @conference_key = conference_key, @division_key = division_key
      FROM dbo.SMG_Teams
     WHERE league_key = @league_key AND season_key = @season_key AND team_slug = @teamSlug
     
    DECLARE @stats TABLE
    (
        team_key VARCHAR(100),
        [column] VARCHAR(100), 
        value VARCHAR(100)
    )
    INSERT INTO @stats (team_key, [column], value)
    SELECT st.team_key, ss.[column], ss.value
      FROM SportsEditDB.dbo.SMG_Standings ss
     INNER JOIN dbo.SMG_Teams st
        ON st.league_key = @league_key AND st.season_key = ss.season_key AND st.team_key = ss.team_key AND st.conference_key = @conference_key
     WHERE ss.season_key = @season_key
            
    DECLARE @standings TABLE
    (
        team_key VARCHAR(100),
        team_abbr VARCHAR(100),
        team_slug VARCHAR(100),
        team_page VARCHAR(100),
        logo VARCHAR(100),
        -- extra
        division_key VARCHAR(100),
        ribbon VARCHAR(100),
        ribbon_order INT,
        -- columns
        wins INT,
        losses INT,
        ties INT,
        overtime_losses INT,
        winning_percentage VARCHAR(100),
        games_back VARCHAR(100),
        standing_points INT,
        points INT,
        conference_winning_percentage VARCHAR(100),
        conference_wins INT,
        conference_losses INT,
        result_effect VARCHAR(100)
    )
    INSERT INTO @standings (team_key, points, result_effect, wins, losses, ties, overtime_losses, conference_wins, conference_losses)
    SELECT p.team_key, ISNULL([points], 0), [result-effect],
           ISNULL([wins], 0), ISNULL([losses], 0), ISNULL([ties], 0), ISNULL([overtime-losses], 0), ISNULL([conference-wins], 0), ISNULL([conference-losses], 0)
      FROM (SELECT team_key, [column], value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.[column] IN (points, [result-effect], wins, losses, ties, [overtime-losses], [conference-wins], [conference-losses])) AS p

    IF (@leagueName = 'wwc')
    BEGIN
        UPDATE s
           SET s.team_abbr = st.team_abbreviation, s.team_slug = st.team_slug, s.division_key = st.division_key
          FROM @standings s
         INNER JOIN dbo.SMG_Teams st
            ON st.league_key = 'wwc' AND st.season_key = @season_key AND st.team_key = s.team_key

        UPDATE s
           SET s.ribbon = sl.division_name
          FROM @standings s
         INNER JOIN dbo.SMG_Leagues sl
            ON sl.league_key = 'wwc' AND sl.season_key = @season_key AND sl.division_key = s.division_key 

        UPDATE @standings
           SET team_page = 'http://www.usatoday.com/sports/soccer/wwc/' + team_slug
    END
    ELSE
    BEGIN
        UPDATE s
           SET s.team_abbr = st.team_abbreviation, s.team_slug = st.team_slug, s.division_key = st.division_key
          FROM @standings s
         INNER JOIN dbo.SMG_Teams st
            ON st.season_key = @season_key AND st.team_key = s.team_key

        UPDATE s
           SET s.ribbon = sl.division_display, s.ribbon_order = sl.division_order
          FROM @standings s
         INNER JOIN dbo.SMG_Leagues sl
            ON sl.league_key = @league_key AND sl.season_key = @season_key AND sl.conference_key = @conference_key AND sl.division_key = s.division_key 
    
        IF (@leagueName = 'mls')
        BEGIN
            UPDATE @standings
               SET team_page = 'http://www.usatoday.com/sports/soccer/mls/' + team_slug
        END
        ELSE
        BEGIN
            UPDATE @standings
               SET team_page = 'http://www.usatoday.com/sports/' + @leagueName + '/' + team_slug
        END
    END

    -- render
    IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw'))
    BEGIN
        UPDATE @standings
           SET logo = @logo_prefix + 'ncaa' + @logo_folder + team_abbr + @logo_suffix
    END
    ELSE IF (@leagueName = 'wwc')
    BEGIN
        UPDATE @standings
           SET logo = @logo_prefix + @flag_folder + team_abbr + @logo_suffix
    END
    ELSE
    BEGIN
        UPDATE @standings
           SET logo = @logo_prefix + @leagueName + @logo_folder + team_abbr + @logo_suffix
    END

    UPDATE @standings
       SET result_effect = ''
     WHERE result_effect IS NULL

    UPDATE @standings
       SET winning_percentage = CASE
                                    WHEN wins + losses = 0 THEN '.000'
                                    WHEN wins + losses = wins THEN '1.00'
                                    ELSE CAST((CAST(wins AS FLOAT) / (wins + losses)) AS DECIMAL(4, 3))
                                END,
           conference_winning_percentage = CASE
                                               WHEN conference_wins + conference_losses = 0 THEN '.000'
                                               WHEN conference_wins + conference_losses = conference_wins THEN '1.00'
                                               ELSE CAST((CAST(conference_wins AS FLOAT) / (conference_wins + conference_losses)) AS DECIMAL(4, 3))
                                           END
           
    UPDATE @standings
       SET winning_percentage = REPLACE(winning_percentage, '0.', '.'),
           conference_winning_percentage = REPLACE(conference_winning_percentage, '0.', '.')

    -- game back
    DECLARE @leaders TABLE
    (
        division_key VARCHAR(100),
        team_key VARCHAR(100),
        wins INT,
        losses INT
    )
    DECLARE @leader_wins INT
    DECLARE @leader_losses INT

    INSERT INTO @leaders (division_key)
    SELECT division_key
      FROM @standings
     GROUP BY division_key
        
    UPDATE l
       SET l.team_key = (SELECT TOP 1 s.team_key
                           FROM @standings s
                          WHERE s.division_key = l.division_key
                          ORDER BY CAST(s.winning_percentage AS FLOAT) DESC)
      FROM @leaders l                            

    UPDATE l
       SET l.wins = s.wins, l.losses = s.losses
      FROM @leaders l
     INNER JOIN @standings s
        ON s.division_key = l.division_key AND s.team_key = l.team_key

    UPDATE s
       SET s.games_back = CAST((CAST((l.wins - s.wins) - (l.losses - s.losses) AS FLOAT) / 2.0) AS DECIMAL(6, 1))
      FROM @standings s
     INNER JOIN @leaders l
        ON l.division_key = s.division_key

    UPDATE @standings
       SET games_back = REPLACE(games_back, '.0', '')

    
    IF (@leagueName = 'mlb')
    BEGIN
        SELECT
	    (
            SELECT div.ribbon,
                   (
                       SELECT s.team_abbr AS short_name, s.wins, s.losses, s.winning_percentage, s.team_page, s.result_effect AS legend_key, s.logo,
                              (CASE WHEN s.games_back = '0' THEN '-' ELSE s.games_back END) AS games_back
                         FROM @standings s
                        WHERE s.ribbon = div.ribbon
                        ORDER BY CAST(s.games_back AS FLOAT) ASC
                          FOR XML RAW('teams'), TYPE
                   )
              FROM @standings div
             GROUP BY div.ribbon, div.ribbon_order
             ORDER BY div.ribbon_order
               FOR XML RAW('standings'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END
    ELSE IF (@leagueName = 'mls')
    BEGIN
        SELECT
	    (
            SELECT div.ribbon,
                  (
                      SELECT s.team_abbr AS short_name, s.wins, s.losses, s.ties, s.standing_points, s.team_page, s.result_effect AS legend_key, s.logo
                        FROM @standings s
                       WHERE s.ribbon = div.ribbon
                       ORDER BY s.standing_points DESC
                         FOR XML RAW('teams'), TYPE
                  )
              FROM @standings div
             GROUP BY div.ribbon, div.ribbon_order
             ORDER BY div.ribbon_order
            FOR XML RAW('standings'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END
    ELSE IF (@leagueName IN ('nba', 'wnba'))
    BEGIN
        SELECT
	    (
            SELECT div.ribbon,
                   (
                       SELECT s.team_abbr AS short_name, s.wins, s.losses, s.winning_percentage, s.team_page, s.result_effect AS legend_key, s.logo,
                              (CASE WHEN s.games_back = '0' THEN '-' ELSE s.games_back END) AS games_back
                         FROM @standings s
                        WHERE s.ribbon = div.ribbon
                        ORDER BY CAST(s.games_back AS FLOAT) ASC
                          FOR XML RAW('teams'), TYPE
                   )
              FROM @standings div
             GROUP BY div.ribbon, div.ribbon_order
             ORDER BY div.ribbon_order
               FOR XML RAW('standings'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END
    ELSE IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw'))
    BEGIN
        SELECT
        (
            SELECT div.ribbon,
                   (
                       SELECT s.team_abbr AS short_name, s.wins, s.losses, s.winning_percentage, s.team_page, s.result_effect AS legend_key, s.logo,
                              CAST(s.conference_wins AS VARCHAR) + '-' + CAST(s.conference_losses AS VARCHAR) AS conference_record
                         FROM @standings s
                        WHERE s.ribbon = div.ribbon
                        ORDER BY CAST(s.conference_winning_percentage AS FLOAT) DESC, s.conference_wins DESC, s.conference_losses ASC
                          FOR XML RAW('teams'), TYPE
                   )
              FROM @standings div
             GROUP BY div.ribbon, div.ribbon_order
             ORDER BY div.ribbon_order
               FOR XML RAW('standings'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END
    ELSE IF (@leagueName = 'nfl')
    BEGIN
        SELECT
	    (
            SELECT div.ribbon,
                   (
                       SELECT s.team_abbr AS short_name, s.wins, s.losses, s.ties, s.winning_percentage, s.team_page, s.result_effect AS legend_key, s.logo
                         FROM @standings s
                        WHERE s.ribbon = div.ribbon
                        ORDER BY CAST(s.winning_percentage AS FLOAT) DESC
                          FOR XML RAW('teams'), TYPE
                   )
              FROM @standings div
             GROUP BY div.ribbon, div.ribbon_order
             ORDER BY div.ribbon_order
               FOR XML RAW('standings'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END
    ELSE IF (@leagueName = 'nhl')
    BEGIN
        SELECT
	    (
            SELECT div.ribbon,
                   (
                       SELECT s.team_abbr AS short_name, s.wins, s.losses, s.overtime_losses, s.standing_points, s.team_page, s.result_effect AS legend_key, s.logo
                         FROM @standings s
                        WHERE s.ribbon = div.ribbon
                        ORDER BY s.standing_points DESC
                          FOR XML RAW('teams'), TYPE
                   )
              FROM @standings div
             GROUP BY div.ribbon, div.ribbon_order
             ORDER BY div.ribbon_order
               FOR XML RAW('standings'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END
    ELSE IF (@leagueName = 'wwc')
    BEGIN
        SELECT
	    (
            SELECT div.ribbon,
                   (
                       SELECT s.team_abbr AS short_name, s.wins, s.losses, s.ties, s.points, s.team_page, s.logo
                         FROM @standings s
                        WHERE s.ribbon = div.ribbon
                        ORDER BY s.standing_points DESC
                          FOR XML RAW('teams'), TYPE
                   )
              FROM @standings div
             GROUP BY div.ribbon
               FOR XML RAW('standings'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END

END

GO
