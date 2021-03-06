USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetStandings_MLB_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[SMG_GetStandings_MLB_XML]
    @seasonKey INT,
    @affiliation VARCHAR(100)
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 09/27/2013
  -- Description: get MLB standings
  -- Update: 12/16/2013 - John Lin - update wild card logic
  --         01/14/2014 - John Lin - add team slug
  --         07/17/2014 - John Lin - update wild card logic
  --         07/23/2014 - John Lin - update wild card logic again
  --         10/14/2014 - John Lin - remove league key from SMG_Standings
  --         02/20/2015 - ikenticus - migrating SMG_Team_Season_Statistics to SMG_Statistics
  --         05/27/2015 - John Lin - swap out sprite
  --         06/04/2015 - ikenticus - eliminate xmlteam league_key for STATS migration
  --         06/16/2015 - John Lin - exclude results not in legend
  --         06/30/2015 - John Lin - STATS migration
  --         08/12/2015 - John Lin - secondary sort
  --         09/21/2015 - ikenticus - adjusting win_loss_ration to 3 decimal places instead of 2
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('mlb')
    DECLARE @logo_prefix VARCHAR(100) = 'http://www.gannett-cdn.com/media/SMG/sports_logos/'
    DECLARE @logo_folder VARCHAR(100) = '-whitebg/30/'
    DECLARE @legend_folder VARCHAR(100) = 'legends/clinched-'
    DECLARE @logo_suffix VARCHAR(100) = '.png'

    DECLARE @legend TABLE
    (
        [source] VARCHAR(100),
        [desc] VARCHAR(100)
    )
    INSERT INTO @legend ([source], [desc])
    VALUES (@logo_prefix + @legend_folder + 'y' + @logo_suffix, 'Clinched Division'),
           (@logo_prefix + @legend_folder + 'x' + @logo_suffix, 'Clinched Playoff Berth'),
           (@logo_prefix + @legend_folder + 'w' + @logo_suffix, 'Clinched Wild Card'),
           (@logo_prefix + @legend_folder + 's' + @logo_suffix, 'Clinched Best Record in League')

    DECLARE @columns TABLE
    (
        display VARCHAR(100),
        tooltip VARCHAR(100),
        [sort]  VARCHAR(100),
        [type]  VARCHAR(100),
        [column] VARCHAR(100)
    )    
    INSERT INTO @columns (display, tooltip, [sort], [type], [column])
    VALUES ('TEAM', 'Team', '', '', 'team'), ('W', 'Wins', 'desc,asc', 'formatted-num', 'wins'),
           ('L', 'Losses', 'asc,desc', 'formatted-num', 'losses'), ('PCT', 'Win-Loss Ratio', 'desc,asc', 'formatted-num', 'win_loss_ratio'),
           ('GB', 'Games Back', 'asc,desc', 'formatted-num', 'games_back'), ('HOME', 'Home Record', 'desc,asc', 'formatted-num', 'home_record'),
           ('ROAD', 'Away Record', 'desc,asc', 'formatted-num', 'away_record'), ('RS', 'Runs Scored', 'desc,asc', 'formatted-num', 'runs_scored'),
           ('RA', 'Runs Allowed', 'desc,asc', 'formatted-num', 'runs_allowed'), ('DIFF', 'Runs Differential', 'desc,asc', 'formatted-num', 'runs_differential'),
           ('L-10', 'L10', 'desc,asc', 'formatted-num', 'l10'), ('STRK', 'Streak', 'desc,asc', 'title-numeric', 'streak')

    DECLARE @standings TABLE
    (
        conference_key VARCHAR(100),
        conference_name VARCHAR(100),
        conference_order INT,
        division_key VARCHAR(100),
        division_name VARCHAR(100),
        division_order INT,
        team_key VARCHAR(100),
        team_abbr VARCHAR(100),
        team_slug VARCHAR(100),
        result_effect VARCHAR(100),
        [skip] INT DEFAULT 0,
        home_wins INT,
        home_losses INT,
        away_wins INT,
        away_losses INT,
        l10_win VARCHAR(100),
        l10_losses VARCHAR(100),
        -- render
        legend VARCHAR(100),
        logo VARCHAR(100),
        team VARCHAR(100),
        link VARCHAR(100),
        wins INT,
        losses INT,
        win_loss_ratio VARCHAR(100),
        games_back VARCHAR(100),
        home_record VARCHAR(100),
        away_record VARCHAR(100),
        runs_scored INT, -- statistics
        runs_allowed INT, -- statistics
        runs_differential VARCHAR(100),
        l10 VARCHAR(100),
        streak VARCHAR(100)
    )
    
    DECLARE @stats TABLE
    (       
        team_key   VARCHAR(100),
        [column]   VARCHAR(100), 
        value      VARCHAR(100)
    )
        
    INSERT INTO @stats (team_key, [column], value)
    SELECT ss.team_key, ss.[column], ss.value
      FROM SportsEditDB.dbo.SMG_Standings ss
     INNER JOIN dbo.SMG_Teams st
        ON st.league_key = @league_key AND ss.season_key = st.season_key AND ss.team_key = st.team_key
     WHERE ss.season_key = @seasonKey AND
           ss.[column] IN ('wins', 'losses', 'winning-percentage', 'games-back', 'home-wins', 'home-losses', 'away-wins', 'away-losses',
                           'points-scored-for', 'points-scored-against', 'last-ten-games-wins', 'last-ten-games-losses', 'streak', 'result-effect')

            
    INSERT INTO @standings (team_key, wins, losses, win_loss_ratio, games_back, home_wins, home_losses, away_wins, away_losses,
                            runs_scored, runs_allowed, l10_win, l10_losses, streak, result_effect)
    SELECT p.team_key, [wins], [losses], [winning-percentage], [games-back], [home-wins], [home-losses], [away-wins], [away-losses],
           [points-scored-for], [points-scored-against], [last-ten-games-wins], [last-ten-games-losses], [streak], [result-effect]
      FROM (SELECT team_key, [column], value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.[column] IN ([wins], [losses], [winning-percentage], [games-back], [home-wins], [home-losses], [away-wins], [away-losses],
                                            [points-scored-for], [points-scored-against], [last-ten-games-wins], [last-ten-games-losses], [streak], [result-effect])) AS p

    UPDATE @standings
       SET win_loss_ratio = CASE
                                WHEN wins + losses = 0 THEN '.000'
                                WHEN wins + losses = wins THEN '1.00'
                                ELSE REPLACE(CAST((CAST(wins AS FLOAT)/ (wins + losses)) AS DECIMAL(4, 3)), '0.', '.')
                            END

    UPDATE @standings
       SET result_effect = ''
     WHERE result_effect IS NULL OR result_effect NOT IN ('y', 'x', 'w', 's')
     
    
    UPDATE s
       SET s.conference_key = sl.conference_key,
           s.conference_name =  sl.conference_display,
           s.conference_order =  sl.conference_order,
           s.division_key =  sl.division_key,
           s.division_name =  sl.division_display,
           s.division_order =  sl.division_order,
           s.team = st.team_first + ' ' + st.team_last,
           s.team_abbr = st.team_abbreviation,
           s.team_slug = st.team_slug
      FROM @standings s
     INNER JOIN dbo.SMG_Teams st
        ON st.team_key = s.team_key AND st.league_key = @league_key AND st.season_key = @seasonKey
     INNER JOIN dbo.SMG_Leagues sl
        On sl.league_key = st.league_key AND sl.season_key = st.season_key AND sl.conference_key = st.conference_key AND sl.division_key = st.division_key

    -- render
    UPDATE @standings
       SET legend = (CASE
                        WHEN result_effect <> '' THEN @logo_prefix + @legend_folder + result_effect + @logo_suffix
                        ELSE ''
                    END),
           logo = @logo_prefix + 'mlb' + @logo_folder + team_abbr + @logo_suffix,
           link = '/sports/mlb/' + team_slug + '/',
           home_record = CAST(home_wins AS VARCHAR(100)) + '-' + CAST(home_losses AS VARCHAR(100)),
           away_record = CAST(away_wins AS VARCHAR(100)) + '-' + CAST(away_losses AS VARCHAR(100)),
           runs_differential = (CASE
                                   WHEN runs_scored > runs_allowed THEN '+' + CAST((runs_scored - runs_allowed) AS VARCHAR(100))
                                   WHEN runs_allowed > runs_scored THEN '-' + CAST((runs_allowed - runs_scored) AS VARCHAR(100))
                                   ELSE '0'
                               END),
           games_back = REPLACE(REPLACE(REPLACE(games_back, '1/2', '.5'), '.0', ''), ' ', ''),
           l10 = l10_win + '-' + l10_losses,                               
           streak = REPLACE(REPLACE(streak, 'Won ', '+'), 'Lost ', '-')

    
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

    IF (@affiliation = 'all')
    BEGIN
        SELECT TOP 1 @leader_wins = wins, @leader_losses = losses
          FROM @standings
         ORDER BY CAST(win_loss_ratio AS FLOAT) DESC

        UPDATE @standings
           SET games_back = CAST((CAST((@leader_wins - wins) - (@leader_losses - losses) AS FLOAT) / 2.0) AS DECIMAL(6, 1))

        UPDATE @standings
           SET games_back = REPLACE(games_back, '.0', '')

        SELECT
	    (
	        SELECT 'MLB' AS ribbon, 'games_back' AS default_column,
	        (
                SELECT s.legend, s.logo, s.team, s.link, s.wins, s.losses, s.win_loss_ratio,
                       (CASE
                           WHEN s.games_back = '0' THEN '-'
                           ELSE s.games_back
                       END) AS games_back,
                       s.home_record, s.away_record, s.runs_scored, s.runs_allowed,
                       s.runs_differential, s.l10, s.streak
                  FROM @standings s
                 ORDER BY CAST(s.games_back AS FLOAT) ASC, CAST(s.win_loss_ratio AS FLOAT) DESC
                   FOR XML RAW('row'), TYPE
            )
            FOR XML RAW('table'), TYPE
        ),
        (
            SELECT display, tooltip, [sort], [type], [column]
              FROM @columns
               FOR XML RAW('column'), TYPE
        ),
        (
            SELECT [source], [desc]
              FROM @legend
               FOR XML RAW('legend'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END
    ELSE IF (@affiliation = 'league')
    BEGIN
        INSERT INTO @leaders (conference_key)
        SELECT conference_key
          FROM @standings
         GROUP BY conference_key

        UPDATE l
           SET l.team_key = (SELECT TOP 1 s.team_key
                               FROM @standings s
                              WHERE s.conference_key = l.conference_key
                              ORDER BY CAST(s.win_loss_ratio AS FLOAT) DESC)
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


        SELECT
	    (
            SELECT conf_s.conference_name AS ribbon, 'games_back' AS default_column,
            (
                SELECT s.legend, s.logo, s.team, s.link, s.wins, s.losses, s.win_loss_ratio,
                       (CASE
                           WHEN s.games_back = '0' THEN '-'
                           ELSE s.games_back
                       END) AS games_back,
                       s.home_record, s.away_record,
                       s.runs_scored, s.runs_allowed, s.runs_differential, s.l10, s.streak
                  FROM @standings s
                 WHERE s.conference_key = conf_s.conference_key
                 ORDER BY CAST(s.games_back AS FLOAT) ASC, CAST(s.win_loss_ratio AS FLOAT) DESC
                   FOR XML RAW('row'), TYPE
            )
            FROM @standings conf_s
           GROUP BY conf_s.conference_key, conf_s.conference_name, conf_s.conference_order
           ORDER BY conf_s.conference_order ASC
             FOR XML RAW('table'), TYPE
        ),
        (
            SELECT display, tooltip, [sort], [type], [column]
              FROM @columns
               FOR XML RAW('column'), TYPE
        ),
        (
            SELECT [source], [desc]
              FROM @legend
               FOR XML RAW('legend'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END
    ELSE IF (@affiliation = 'wild-card')
    BEGIN
        INSERT INTO @leaders (conference_key, division_key)
        SELECT conference_key, division_key
          FROM @standings
         GROUP BY conference_key, division_key
         
        UPDATE l
           SET l.team_key = (SELECT TOP 1 s.team_key
                               FROM @standings s
                              WHERE s.conference_key = l.conference_key AND s.division_key = l.division_key
                              ORDER BY CAST(s.win_loss_ratio AS FLOAT) DESC)
          FROM @leaders l

        DELETE s
          FROM @standings s
         INNER JOIN @leaders l
            ON l.team_key = s.team_key

        DELETE @leaders
        
        INSERT INTO @leaders (conference_key)
        SELECT conference_key
          FROM @standings
         GROUP BY conference_key

        UPDATE l
           SET l.team_key = (SELECT TOP 1 s.team_key
                               FROM @standings s
                              WHERE s.conference_key = l.conference_key
                              ORDER BY CAST(s.win_loss_ratio AS FLOAT) DESC)
          FROM @leaders l

        UPDATE s
           SET s.[skip] = 1
          FROM @standings s
         INNER JOIN @leaders l
            ON l.team_key = s.team_key

        DELETE @leaders

        INSERT INTO @leaders (conference_key)
        SELECT conference_key
          FROM @standings
         GROUP BY conference_key

        UPDATE l
           SET l.team_key = (SELECT TOP 1 s.team_key
                               FROM @standings s
                              WHERE s.conference_key = l.conference_key AND s.[skip] = 0
                              ORDER BY CAST(s.win_loss_ratio AS FLOAT) DESC)
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

        UPDATE s
           SET s.games_back = '0'
          FROM @standings s
         INNER JOIN @leaders l
            ON l.team_key = s.team_key        
        
        UPDATE @standings
           SET games_back = '0'
         WHERE [skip] = 1

           
        SELECT
	    (
            SELECT conf_s.conference_name AS ribbon, 'games_back' AS default_column,
            (
                SELECT s.legend, s.logo, s.team, s.link, s.wins, s.losses, s.win_loss_ratio,
                       (CASE
                           WHEN s.games_back = '0' THEN '-'
                           ELSE s.games_back
                       END) AS games_back,
                       s.home_record, s.away_record,
                       s.runs_scored, s.runs_allowed, s.runs_differential, s.l10, s.streak
                  FROM @standings s
                 WHERE s.conference_key = conf_s.conference_key
                 ORDER BY CAST(s.games_back AS FLOAT) ASC, CAST(s.win_loss_ratio AS FLOAT) DESC
                   FOR XML RAW('row'), TYPE
            )
            FROM @standings conf_s
           GROUP BY conf_s.conference_key, conf_s.conference_name, conf_s.conference_order
           ORDER BY conf_s.conference_order ASC
             FOR XML RAW('table'), TYPE
        ),
        (
            SELECT display, tooltip, [sort], [type], [column]
              FROM @columns
               FOR XML RAW('column'), TYPE
        ),
        (
            SELECT [source], [desc]
              FROM @legend
               FOR XML RAW('legend'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END
    ELSE -- 'division'
    BEGIN
        INSERT INTO @leaders (conference_key, division_key)
        SELECT conference_key, division_key
          FROM @standings
         GROUP BY conference_key, division_key
        
        UPDATE l
           SET l.team_key = (SELECT TOP 1 s.team_key
                               FROM @standings s
                              WHERE s.conference_key = l.conference_key aND s.division_key = l.division_key
                              ORDER BY CAST(s.win_loss_ratio AS FLOAT) DESC)
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

        SELECT
	    (
            SELECT div_s.division_name AS ribbon, 'games_back' AS default_column,
            (
                SELECT s.legend, s.logo, s.team, s.link, s.wins, s.losses, s.win_loss_ratio,
                       (CASE
                           WHEN s.games_back = '0' THEN '-'
                           ELSE s.games_back
                       END) AS games_back,
                       s.home_record, s.away_record, s.runs_scored, s.runs_allowed,
                       s.runs_differential, s.l10, s.streak
                  FROM @standings s
                 WHERE s.conference_key = div_s.conference_key AND s.division_key = div_s.division_key
                 ORDER BY CAST(s.games_back AS FLOAT) ASC, CAST(s.win_loss_ratio AS FLOAT) DESC
                   FOR XML RAW('row'), TYPE
            )
            FROM @standings div_s
           GROUP BY div_s.conference_key, div_s.conference_order, div_s.division_key, div_s.division_name, div_s.division_order
           ORDER BY div_s.conference_order ASC, div_s.division_order ASC
             FOR XML RAW('table'), TYPE
        ),
        (
            SELECT display, tooltip, [sort], [type], [column]
              FROM @columns
               FOR XML RAW('column'), TYPE
        ),
        (
            SELECT [source], [desc]
              FROM @legend
               FOR XML RAW('legend'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END

    SET NOCOUNT OFF
END

GO
