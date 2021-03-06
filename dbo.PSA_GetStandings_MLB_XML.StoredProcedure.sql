USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetStandings_MLB_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PSA_GetStandings_MLB_XML]
    @affiliation VARCHAR(100)
AS
-- =============================================
-- Author:		John Lin
-- Create date:	07/02/2014
-- Description:	get MLB standings
-- Update:		07/17/2014 - John Lin - exclude All Stars
--              09/24/2014 - John Lin - update wild card logic
--              10/09/2014 - John Lin - whitebg
--              10/14/2014 - John Lin - remove league key from SMG_Standings
--				11/11/2014 - ikenticus - updating GB to WCGB for wild-card
--				05/14/2015 - ikenticus - obtain league_key from SMG_fnGetLeagueKey
--              06/16/2015 - John Lin - exclude results not in legend
--              06/30/2015 - John Lin - STATS migration
--              08/12/2015 - John Lin - secondary sort
--              08/26/2015 - ikenticus - sort by _order, not _key
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('mlb')
    DECLARE @season_key INT
    
    SELECT @season_key = season_key
      FROM dbo.SMG_Default_Dates
     WHERE league_key = 'mlb' AND page = 'standings'

    DECLARE @columns TABLE
    (
        id INT IDENTITY(1, 1) PRIMARY KEY,
        column_name    VARCHAR(100),
        column_display VARCHAR(100)
    )
    DECLARE @stats TABLE
    (       
        team_key   VARCHAR(100),
        [column]   VARCHAR(100), 
        value      VARCHAR(100)
    )

    INSERT INTO @columns (column_name, column_display)
    VALUES ('name', 'TEAM'), ('wins', 'W'), ('losses', 'L'), ('games_back', 'GB'), ('l10', 'L-10')

	UPDATE @columns
	   SET column_display = 'WCGB'
	 WHERE column_name = 'games_back' AND @affiliation = 'wild-card'

    INSERT INTO @stats (team_key, [column], value)
    SELECT ss.team_key, ss.[column], ss.value
      FROM SportsEditDB.dbo.SMG_Standings ss
     INNER JOIN dbo.SMG_Teams st
        ON st.league_key = @league_key AND ss.season_key = st.season_key AND ss.team_key = st.team_key
     WHERE ss.season_key = @season_key AND
           ss.[column] IN ('wins', 'losses', 'games-back', 'result-effect', 'last-ten-games-wins', 'last-ten-games-losses', 'winning-percentage')

    DECLARE @standings TABLE
    (
        conference_order INT,
        conference_key VARCHAR(100),
        conference_display VARCHAR(100),
        division_order INT,
        division_key VARCHAR(100),
        division_display VARCHAR(100),
        team_key VARCHAR(100),
        -- render
        first_name VARCHAR(100),
        last_name VARCHAR(100),
        wins INT,
        losses INT,
        games_back VARCHAR(100),
        result_effect VARCHAR(100),
        [skip] INT DEFAULT 0,
        logo VARCHAR(100),
        -- extra
        l10_win VARCHAR(100),
        l10_losses VARCHAR(100),
        winning_percentage VARCHAR(100),
        team_abbreviation VARCHAR(100)
    )    
            
    INSERT INTO @standings (team_key, wins, losses, games_back, result_effect, l10_win, l10_losses, winning_percentage)
    SELECT p.team_key, [wins], [losses], [games-back], [result-effect], [last-ten-games-wins], [last-ten-games-losses], [winning-percentage]
      FROM (SELECT team_key, [column], value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.[column] IN ([wins], [losses], [games-back], [result-effect], [last-ten-games-wins], [last-ten-games-losses], [winning-percentage])) AS p

    UPDATE @standings
       SET winning_percentage = CASE
                                    WHEN wins + losses = 0 THEN '.000'
                                    WHEN wins + losses = wins THEN '1.00'
                                    ELSE REPLACE(CAST((CAST(wins AS FLOAT)/ (wins + losses)) AS DECIMAL(4, 3)), '0.', '.')
                                END

    UPDATE @standings
       SET result_effect = ''
     WHERE result_effect IS NULL OR result_effect NOT IN ('y', 'x', 'w', 's')
    
    UPDATE s
       SET s.conference_order = sl.conference_order,
		   s.conference_key = sl.conference_key,
           s.conference_display = sl.conference_display,
           s.division_order = sl.division_order,
           s.division_key = sl.division_key,
           s.division_display = sl.division_display,
           s.first_name = st.team_first,
           s.last_name = st.team_last,
           s.team_abbreviation = st.team_abbreviation
      FROM @standings s
     INNER JOIN dbo.SMG_Teams st
        ON st.team_key = s.team_key AND st.league_key = @league_key AND st.season_key = @season_key
     INNER JOIN dbo.SMG_Leagues sl
        On sl.league_key = st.league_key AND sl.season_key = st.season_key AND sl.conference_key = st.conference_key AND sl.division_key = st.division_key

    -- exclude ALL STARS
    DELETE @standings
     WHERE first_name = 'All-Stars' OR last_name = 'All-Stars'

    -- render
    UPDATE @standings
       SET games_back = REPLACE(REPLACE(REPLACE(games_back, '1/2', '.5'), '.0', ''), ' ', ''),
           logo = 'http://www.gannett-cdn.com/media/SMG/sports_logos/mlb-whitebg/110/' + team_abbreviation + '.png'

    
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

    IF (@affiliation = 'league')
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
	            SELECT column_name, column_display
		          FROM @columns
		         ORDER BY id ASC
    		       FOR XML PATH('columns'), TYPE
	        ),
            (
                SELECT s.last_name AS name, s.wins, s.losses, s.l10_win + '-' + s.l10_losses AS l10, s.logo, s.result_effect AS [key],
                       CASE WHEN s.games_back = '0' THEN '-' ELSE s.games_back END AS games_back
                  FROM @standings s
                 WHERE s.conference_key = conf_s.conference_key
                 ORDER BY CAST(s.games_back AS FLOAT) ASC, CAST(s.winning_percentage AS FLOAT) DESC
                   FOR XML RAW('rows'), TYPE
            )
            FROM @standings conf_s
           GROUP BY conf_s.conference_key, conf_s.conference_display, conf_s.conference_order
           ORDER BY conf_s.conference_order ASC
             FOR XML RAW('standings'), TYPE
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
	            SELECT column_name, column_display
		          FROM @columns
		         ORDER BY id ASC
    		       FOR XML PATH('columns'), TYPE
	        ),
            (
                SELECT s.last_name AS name, s.wins, s.losses, s.l10_win + '-' + s.l10_losses AS l10, s.logo, s.result_effect AS [key],
                       CASE WHEN s.games_back = '0' THEN '-' ELSE s.games_back END AS games_back
                  FROM @standings s
                 WHERE s.conference_key = conf_s.conference_key
                 ORDER BY CAST(s.games_back AS FLOAT) ASC, CAST(s.winning_percentage AS FLOAT) DESC
                   FOR XML RAW('rows'), TYPE
            )
            FROM @standings conf_s
           GROUP BY conf_s.conference_key, conf_s.conference_display, conf_s.conference_order
           ORDER BY conf_s.conference_order ASC
             FOR XML RAW('standings'), TYPE
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
	            SELECT column_name, column_display
		          FROM @columns
		         ORDER BY id ASC
    		       FOR XML PATH('columns'), TYPE
	        ),
            (
                SELECT s.last_name AS name, s.wins, s.losses, s.l10_win + '-' + s.l10_losses AS l10, s.logo, s.result_effect AS [key],
                       CASE WHEN s.games_back = '0' THEN '-' ELSE s.games_back END AS games_back
                  FROM @standings s
                 WHERE s.conference_key = div_s.conference_key AND s.division_key = div_s.division_key
                 ORDER BY CAST(s.games_back AS FLOAT) ASC, CAST(s.winning_percentage AS FLOAT) DESC
                   FOR XML RAW('rows'), TYPE
            )
            FROM @standings div_s
           GROUP BY div_s.conference_key, div_s.division_key, div_s.division_display, div_s.conference_order, div_s.division_order
           ORDER BY div_s.conference_order ASC, div_s.division_order ASC
             FOR XML RAW('standings'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END

    SET NOCOUNT OFF
END

GO
