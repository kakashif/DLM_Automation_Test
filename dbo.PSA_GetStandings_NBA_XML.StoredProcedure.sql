USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetStandings_NBA_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PSA_GetStandings_NBA_XML]
    @leagueName VARCHAR(100),
    @affiliation VARCHAR(100)
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 07/02/2013
  -- Description: get NBA/WNBA standings
  -- Update: 10/09/2014 - John Lin - whitebg
  --         10/14/2014 - John Lin - remove league key from SMG_Standings
  --         05/14/2015 - ikenticus - obtain league_key from SMG_fnGetLeagueKey
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @season_key INT
    
    SELECT @season_key = season_key
      FROM dbo.SMG_Default_Dates
     WHERE league_key = @leagueName AND page = 'standings'
    
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
    VALUES ('name', 'TEAM'), ('wins', 'W'), ('losses', 'L'), ('game_back', 'GB'), ('l10', 'L-10')

    INSERT INTO @stats (team_key, [column], value)
    SELECT ss.team_key, ss.[column], ss.value
      FROM SportsEditDB.dbo.SMG_Standings ss
     INNER JOIN dbo.SMG_Teams st
        ON st.league_key = @league_key AND ss.season_key = st.season_key AND ss.team_key = st.team_key
     WHERE ss.season_key = @season_key AND
           ss.[column] IN ('wins', 'losses', 'games-back', 'result-effect', 'last-ten-games-wins', 'last-ten-games-losses', 'winning-percentage')

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
        first_name VARCHAR(100),
        last_name VARCHAR(100),
        wins INT,
        losses INT,
        games_back VARCHAR(100),
        result_effect VARCHAR(100),
        logo VARCHAR(100),
        -- extra
        l10_wins VARCHAR(100),
        l10_losses VARCHAR(100),
        winning_percentage VARCHAR(100),
        team_abbreviation VARCHAR(100)
    )
           
    INSERT INTO @standings (team_key, wins, losses, games_back, result_effect, l10_wins, l10_losses, winning_percentage)
    SELECT p.team_key, [wins], [losses], [games-back], [result-effect], [last-ten-games-wins], [last-ten-games-losses], [winning-percentage]
      FROM (SELECT team_key, [column], value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.[column] IN ([wins], [losses], [games-back], [result-effect], [last-ten-games-wins], [last-ten-games-losses], [winning-percentage])) AS p    
    
    UPDATE s
       SET s.conference_key = sl.conference_key,
           s.conference_name =  sl.conference_name,
           s.conference_order =  sl.conference_order,
           s.division_key =  sl.division_key,
           s.division_name =  sl.division_name,
           s.division_order =  sl.division_order,
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
           logo = 'http://www.gannett-cdn.com/media/SMG/sports_logos/' + @leagueName + '-whitebg/110/' + team_abbreviation + '.png'


    DECLARE @leaders TABLE
    (
        [key] VARCHAR(100),
        team_key VARCHAR(100),
        wins INT,
        losses INT
    )
    DECLARE @leader_wins INT
    DECLARE @leader_losses INT

    IF (@affiliation = 'division')
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

        UPDATE @standings
           SET games_back = REPLACE(games_back, '.0', '')

         
        SELECT
	    (
            SELECT div_s.division_name AS ribbon,
            (
    	        SELECT column_name, column_display
		          FROM @columns
		         ORDER BY id ASC
	    	       FOR XML PATH('columns'), TYPE
    	    ),
            (
                SELECT s.last_name AS name, s.wins, s.losses, l10_wins + '-' + l10_losses AS l10, s.logo, s.result_effect AS [key],
                       CASE WHEN s.games_back = '0' THEN '-' ELSE s.games_back END AS game_back
                  FROM @standings s
                 WHERE s.division_key = div_s.division_key
                 ORDER BY CAST(s.games_back AS FLOAT) ASC
                   FOR XML RAW('rows'), TYPE
            )
            FROM @standings div_s
           GROUP BY div_s.conference_order, div_s.division_key, div_s.division_name, div_s.division_order
           ORDER BY div_s.conference_order, div_s.division_order
             FOR XML RAW('standings'), TYPE
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

        UPDATE @standings
           SET games_back = REPLACE(games_back, '.0', '')


        SELECT
	    (
            SELECT conf_s.conference_name AS ribbon,
            (
    	        SELECT column_name, column_display
		          FROM @columns
		         ORDER BY id ASC
	    	       FOR XML PATH('columns'), TYPE
    	    ),
            (
                SELECT s.last_name AS name, s.wins, s.losses, l10_wins + '-' + l10_losses AS l10, s.logo, s.result_effect AS [key],
                       CASE WHEN s.games_back = '0' THEN '-' ELSE s.games_back END AS game_back
                  FROM @standings s
                 WHERE s.conference_key = conf_s.conference_key
                 ORDER BY CAST(s.games_back AS FLOAT) ASC
                   FOR XML RAW('rows'), TYPE
            )
            FROM @standings conf_s
           GROUP BY conf_s.conference_key, conf_s.conference_name, conf_s.conference_order
           ORDER BY conf_s.conference_order
             FOR XML RAW('standings'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END

    SET NOCOUNT OFF
END 

GO
