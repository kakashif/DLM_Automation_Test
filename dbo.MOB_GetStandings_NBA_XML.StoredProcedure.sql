USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[MOB_GetStandings_NBA_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[MOB_GetStandings_NBA_XML]
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @affiliation VARCHAR(100)
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 09/27/2013
  -- Description: get NBA/WNBA standings for mobile
  -- Update: 10/14/2014 - John Lin - remove league key from SMG_Standings
  --         12/19/2014 - John Lin - whitebg
  --         07/01/2015 - ikenticus - using league_key function for STATS
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)

    DECLARE @standings TABLE
    (
        conference_key VARCHAR(100),
        conference_name VARCHAR(100),
        conference_order INT,
        division_key VARCHAR(100),
        division_name VARCHAR(100),
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
     
    
    UPDATE s
       SET s.conference_key = sl.conference_key,
           s.conference_name =  sl.conference_name,
           s.conference_order =  sl.conference_order,
           s.division_key =  sl.division_key,
           s.division_name =  sl.division_name,
           s.division_order =  sl.division_order,
           s.long_name = st.team_first + ' ' + st.team_last,
           s.team_abbreviation = st.team_abbreviation,
           s.team_page = 'http://www.usatoday.com/sports/' + @leagueName + '/' + st.team_slug
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
     WHERE result_effect IS NULL

    UPDATE @standings
       SET logo = 'http://www.gannett-cdn.com/media/SMG/sports_logos/' + @leagueName + '-whitebg/22/' + team_abbreviation + '.png'


    DECLARE @leaders TABLE
    (
        [key] VARCHAR(100),
        team_key VARCHAR(100),
        wins INT,
        losses INT
    )
    DECLARE @leader_wins INT
    DECLARE @leader_losses INT

    IF (@affiliation = 'league')
    BEGIN
        SELECT TOP 1 @leader_wins = wins, @leader_losses = losses
          FROM @standings
         ORDER BY CAST(winning_percentage AS FLOAT) DESC

        UPDATE @standings
           SET games_back = CAST((CAST((@leader_wins - wins) - (@leader_losses - losses) AS FLOAT) / 2.0) AS DECIMAL(6, 1))

        SELECT
	    (
	        SELECT UPPER(@leagueName) AS ribbon,
	        (
                SELECT s.team_abbreviation AS short_name, s.long_name, s.wins, s.losses, s.winning_percentage,
                       (CASE
                           WHEN s.games_back = '0' THEN '-'
                           ELSE s.games_back
                       END) AS games_back,
                       s.team_page, s.result_effect AS legend_key, logo
                  FROM @standings s
                 ORDER BY CAST(s.games_back AS FLOAT) ASC
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
    ELSE IF (@affiliation = 'division')
    BEGIN
        INSERT INTO @leaders ([key])
        SELECT division_key
          FROM @standings
         GROUP BY division_key
        
        UPDATE @leaders
           SET team_key = (SELECT TOP 1 team_key
                             FROM @standings
                            WHERE division_key = [key]
                            ORDER BY CAST(winning_percentage AS FLOAT) DESC)

        UPDATE l
           SET l.wins = s.wins, l.losses = s.losses
          FROM @leaders l
         INNER JOIN @standings s
            ON s.division_key = l.[key] AND s.team_key = l.team_key

        UPDATE s
           SET s.games_back = CAST((CAST((l.wins - s.wins) - (l.losses - s.losses) AS FLOAT) / 2.0) AS DECIMAL(6, 1))
          FROM @standings s
         INNER JOIN @leaders l
            ON l.[key] = s.division_key

        SELECT
	    (
            SELECT div_s.division_name AS ribbon,
            (
                SELECT s.team_abbreviation AS short_name, s.long_name, s.wins, s.losses, s.winning_percentage,
                       (CASE
                           WHEN s.games_back = '0' THEN '-'
                           ELSE s.games_back
                       END) AS games_back,
                       s.team_page, s.result_effect AS legend_key, logo
                  FROM @standings s
                 WHERE s.division_key = div_s.division_key
                 ORDER BY CAST(s.games_back AS FLOAT) ASC
                   FOR XML RAW('teams'), TYPE
            )
            FROM @standings div_s
           GROUP BY div_s.conference_order, div_s.division_key, div_s.division_name, div_s.division_order
           ORDER BY div_s.conference_order, div_s.division_order
             FOR XML RAW('standings'), TYPE
        ),
        (
            SELECT @seasonKey AS [year], @affiliation AS affiliation
               FOR XML RAW('defaults'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END
    ELSE -- 'conference'
    BEGIN
        INSERT INTO @leaders ([key])
        SELECT conference_key
          FROM @standings
         GROUP BY conference_key
        
        UPDATE @leaders
           SET team_key = (SELECT TOP 1 team_key
                             FROM @standings
                            WHERE conference_key = [key]
                            ORDER BY CAST(winning_percentage AS FLOAT) DESC)

        UPDATE l
           SET l.wins = s.wins, l.losses = s.losses
          FROM @leaders l
         INNER JOIN @standings s
            ON s.conference_key = l.[key] AND s.team_key = l.team_key

        UPDATE s
           SET s.games_back = CAST((CAST((l.wins - s.wins) - (l.losses - s.losses) AS FLOAT) / 2.0) AS DECIMAL(6, 1))
          FROM @standings s
         INNER JOIN @leaders l
            ON l.[key] = s.conference_key

        SELECT
	    (
            SELECT conf_s.conference_name AS ribbon,
            (
                SELECT s.team_abbreviation AS short_name, s.long_name, s.wins, s.losses, s.winning_percentage,
                       (CASE
                           WHEN s.games_back = '0' THEN '-'
                           ELSE s.games_back
                       END) AS games_back,
                       s.team_page, s.result_effect AS legend_key, logo
                  FROM @standings s
                 WHERE s.conference_key = conf_s.conference_key
                 ORDER BY CAST(s.games_back AS FLOAT) ASC
                   FOR XML RAW('teams'), TYPE
            )
            FROM @standings conf_s
           GROUP BY conf_s.conference_key, conf_s.conference_name, conf_s.conference_order
           ORDER BY conf_s.conference_order
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
