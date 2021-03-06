USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[MOB_GetStandings_MLB_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[MOB_GetStandings_MLB_XML]
    @seasonKey INT,
    @affiliation VARCHAR(100)
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 01/07/2014
  -- Description: get MLB standings for mobile
  -- Update: 07/16/2014 - John Lin - fix wild card logic
  --         09/24/2014 - John Lin - update wild card logic again
  --         10/14/2014 - John Lin - remove league key from SMG_Standings
  --         12/19/2014 - John Lin - whitebg
  --         06/16/2015 - John Lin - exclude results not in legend
  --         06/23/2015 - John Lin - STATS migration
  --         06/29/2015 - John Lin - use display for render and key for sort
  --         06/30/2015 - John Lin - STATS migration
  --         08/12/2015 - John Lin - secondary sort
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('mlb')

    DECLARE @standings TABLE
    (
        conference_key VARCHAR(100),
        conference_display VARCHAR(100),
        conference_order INT,
        division_key VARCHAR(100),
        division_display VARCHAR(100),
        division_order INT,
        team_key VARCHAR(100),
        -- render
        team_abbreviation VARCHAR(100),
        long_name VARCHAR(100),
        wins INT,
        losses INT,
        winning_percentage VARCHAR(100),
        games_back VARCHAR(100),
        team_page VARCHAR(100),
        result_effect VARCHAR(100),
        [skip] INT DEFAULT 0,
        logo VARCHAR(100)
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
     WHERE ss.season_key = @seasonKey AND ss.[column] IN ('wins', 'losses', 'winning-percentage', 'games-back', 'result-effect')

            
    INSERT INTO @standings (team_key, wins, losses, winning_percentage, games_back, result_effect)
    SELECT p.team_key, [wins], [losses], [winning-percentage], [games-back], [result-effect]
      FROM (SELECT team_key, [column], value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.[column] IN ([wins], [losses], [winning-percentage], [games-back], [result-effect])) AS p
     
    UPDATE @standings
       SET winning_percentage = CASE
                                    WHEN wins + losses = 0 THEN '.000'
                                    WHEN wins + losses = wins THEN '1.00'
                                    ELSE REPLACE(CAST((CAST(wins AS FLOAT)/ (wins + losses)) AS DECIMAL(4, 3)), '0.', '.')
                                END
    
    UPDATE s
       SET s.conference_key = sl.conference_key,
           s.conference_display = sl.conference_display,
           s.conference_order = sl.conference_order,
           s.division_key = sl.division_key,
           s.division_display = sl.division_display,
           s.division_order = sl.division_order,
           s.long_name = st.team_first + ' ' + st.team_last,
           s.team_abbreviation = st.team_abbreviation,
           s.team_page = 'http://www.usatoday.com/sports/mlb/' + st.team_slug
      FROM @standings s
     INNER JOIN dbo.SMG_Teams st
        ON st.team_key = s.team_key AND st.league_key = @league_key AND st.season_key = @seasonKey
     INNER JOIN dbo.SMG_Leagues sl
        On sl.league_key = st.league_key AND sl.season_key = st.season_key AND sl.conference_key = st.conference_key AND sl.division_key = st.division_key


    -- render
    UPDATE @standings
       SET games_back = REPLACE(REPLACE(REPLACE(games_back, '1/2', '.5'), '.0', ''), ' ', '')

    UPDATE @standings
       SET result_effect = ''
     WHERE result_effect IS NULL OR result_effect NOT IN ('y', 'x', 'w', 's')

    UPDATE @standings
       SET logo = 'http://www.gannett-cdn.com/media/SMG/sports_logos/mlb-whitebg/22/' + team_abbreviation + '.png'


    
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
         ORDER BY CAST(winning_percentage AS FLOAT) DESC

        UPDATE @standings
           SET games_back = CAST((CAST((@leader_wins - wins) - (@leader_losses - losses) AS FLOAT) / 2.0) AS DECIMAL(6, 1))

        UPDATE @standings
           SET games_back = REPLACE(games_back, '.0', '')

        SELECT
	    (
	        SELECT 'MLB' AS ribbon,
	        (
                SELECT s.team_abbreviation AS short_name, s.long_name, s.wins, s.losses, s.winning_percentage,
                       (CASE
                           WHEN s.games_back = '0' THEN '-'
                           ELSE s.games_back
                       END) AS games_back,
                       s.team_page, s.result_effect AS legend_key, logo
                  FROM @standings s
                 ORDER BY CAST(s.games_back AS FLOAT) ASC, CAST(s.winning_percentage AS FLOAT) DESC
                   FOR XML RAW('teams'), TYPE
            )
            FOR XML RAW('standings'), TYPE
        ),
        (
            SELECT @seasonKey AS [year], @affiliation AS affiliation
               FOR XML RAW('defaults'), TYPE
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
           
        SELECT
	    (
            SELECT conf_s.conference_display AS ribbon,
            (
                SELECT s.team_abbreviation AS short_name, s.long_name, s.wins, s.losses, s.winning_percentage,
                       (CASE
                           WHEN s.games_back = '0' THEN '-'
                           ELSE s.games_back
                       END) AS games_back,
                       s.team_page, s.result_effect AS legend_key, logo
                  FROM @standings s
                 WHERE s.conference_key = conf_s.conference_key
                 ORDER BY CAST(s.games_back AS FLOAT) ASC, CAST(s.winning_percentage AS FLOAT) DESC
                   FOR XML RAW('teams'), TYPE
            )
            FROM @standings conf_s
           GROUP BY conf_s.conference_key, conf_s.conference_display, conf_s.conference_order
           ORDER BY conf_s.conference_order ASC
             FOR XML RAW('standings'), TYPE
        ),
        (
            SELECT @seasonKey AS [year], @affiliation AS affiliation
               FOR XML RAW('defaults'), TYPE
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
                            ORDER BY CAST(s.winning_percentage AS FLOAT) DESC)
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
                              ORDER BY CAST(s.winning_percentage AS FLOAT) DESC)
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
            SELECT conf_s.conference_display AS ribbon,
            (
                SELECT s.team_abbreviation AS short_name, s.long_name, s.wins, s.losses, s.winning_percentage,
                       (CASE
                           WHEN s.games_back = '0' THEN '-'
                           ELSE s.games_back
                       END) AS games_back,
                       s.team_page, s.result_effect AS legend_key, logo
                  FROM @standings s
                 WHERE s.conference_key = conf_s.conference_key
                 ORDER BY CAST(s.games_back AS FLOAT) ASC, CAST(s.winning_percentage AS FLOAT) DESC
                   FOR XML RAW('teams'), TYPE
            )
            FROM @standings conf_s
           GROUP BY conf_s.conference_key, conf_s.conference_display, conf_s.conference_order
           ORDER BY conf_s.conference_order ASC
             FOR XML RAW('standings'), TYPE
        ),
        (
            SELECT @seasonKey AS [year], @affiliation AS affiliation
               FOR XML RAW('defaults'), TYPE
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
                              WHERE s.conference_key = l.conference_key AND s.division_key = l.division_key
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

        SELECT
	    (
            SELECT div_s.division_display AS ribbon,
            (
                SELECT s.team_abbreviation AS short_name, s.long_name, s.wins, s.losses, s.winning_percentage,
                       (CASE
                           WHEN s.games_back = '0' THEN '-'
                           ELSE s.games_back
                       END) AS games_back,
                       s.team_page, s.result_effect AS legend_key, logo
                  FROM @standings s
                 WHERE s.conference_key = div_s.conference_key AND s.division_key = div_s.division_key
                 ORDER BY CAST(s.games_back AS FLOAT) ASC, CAST(s.winning_percentage AS FLOAT) DESC
                   FOR XML RAW('teams'), TYPE
            )
            FROM @standings div_s
           GROUP BY div_s.conference_key, div_s.conference_order, div_s.division_key, div_s.division_display, div_s.division_order
           ORDER BY div_s.conference_order ASC, div_s.division_order ASC
             FOR XML RAW('standings'), TYPE
        ),
        (
            SELECT @seasonKey AS [year], @affiliation AS affiliation
               FOR XML RAW('defaults'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END

    SET NOCOUNT OFF
END

GO
