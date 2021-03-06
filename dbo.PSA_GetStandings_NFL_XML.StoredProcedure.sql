USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetStandings_NFL_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PSA_GetStandings_NFL_XML]
    @affiliation VARCHAR(100)
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 07/02/2014
  -- Description: get NFL standings
  -- Update: 10/09/2014 - John Lin - whitebg
  --         10/14/2014 - John Lin - remove league key from SMG_Standings
  --         05/14/2015 - ikenticus - obtain league_key from SMG_fnGetLeagueKey
  --         07/01/2015 - ikenticus - utilize conf/div rank from STATS when available
  --         08/05/2015 - John Lin - SDI migration
  --         09/14/2015 - John Lin - default null to zero
  --         10/12/2015 - John Lin - additional sort
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('nfl')
    DECLARE @season_key INT
    
    SELECT @season_key = season_key
      FROM dbo.SMG_Default_Dates
     WHERE league_key = 'nfl' AND page = 'standings'

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
    VALUES ('name', 'TEAM'), ('wins', 'W'), ('losses', 'L'), ('ties', 'T')

    INSERT INTO @stats (team_key, [column], value)
    SELECT ss.team_key, ss.[column], ss.value
      FROM SportsEditDB.dbo.SMG_Standings ss
     INNER JOIN dbo.SMG_Teams st
        ON st.league_key = @league_key AND ss.season_key = st.season_key AND ss.team_key = st.team_key
     WHERE ss.season_key = @season_key

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
        name VARCHAR(100),
        wins INT,
        losses INT,
        ties INT,
        result_effect VARCHAR(100),
        logo VARCHAR(100),
        -- extra
        [away-wins] INT,
        [away-losses] INT,
        [away-ties] INT,
        [home-wins] INT,
        [home-losses] INT,
        [home-ties] INT,
        [wins-percentage] VARCHAR(100),
        team_abbreviation VARCHAR(100)
    )

    INSERT INTO @standings (team_key, [away-wins], [away-losses], [away-ties], [home-wins], [home-losses], [home-ties], result_effect)
    SELECT p.team_key, ISNULL([away-wins], 0), ISNULL([away-losses], 0), ISNULL([away-ties], 0),
           ISNULL([home-wins], 0), ISNULL([home-losses], 0), ISNULL([home-ties], 0), result_effect
      FROM (SELECT team_key, [column], value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.[column] IN ([away-wins], [away-losses], [away-ties], [home-wins], [home-losses], [home-ties], result_effect)) AS p

    UPDATE @standings
       SET wins = [away-wins] + [home-wins],
           losses = [away-losses] + [home-losses],
           ties = [away-ties] + [home-ties]

    UPDATE @standings
       SET [wins-percentage] = CASE
                                   WHEN wins + losses + ties = 0 THEN '.000'
                                   WHEN wins + losses + ties = wins THEN '1.00'
                                   ELSE CAST((CAST(wins + (ties * 0.5) AS FLOAT) / (wins + losses + ties)) AS DECIMAL(4, 3))
                               END

    UPDATE s
       SET s.conference_key = sl.conference_key,
           s.conference_display =  sl.conference_display,
           s.conference_order =  sl.conference_order,
           s.division_key =  sl.division_key,
           s.division_display =  sl.division_display,
           s.division_order =  sl.division_order,
           s.name = st.team_last,
           s.team_abbreviation = st.team_abbreviation
      FROM @standings s
     INNER JOIN dbo.SMG_Teams st
        ON st.team_key = s.team_key AND st.league_key = @league_key AND st.season_key = @season_key
     INNER JOIN dbo.SMG_Leagues sl
        On sl.league_key = st.league_key AND sl.season_key = st.season_key AND sl.conference_key = st.conference_key AND sl.division_key = st.division_key

    -- render
    UPDATE @standings
       SET logo = dbo.SMG_fnTeamLogo('nfl', team_abbreviation, '110')

    IF (@affiliation = 'conference')
    BEGIN
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
                SELECT s.name, s.wins, s.losses, s.ties, s.logo, s.result_effect AS [key]
                  FROM @standings s
                 WHERE s.conference_key = conf_s.conference_key
                 ORDER BY CAST(s.[wins-percentage] AS FLOAT) DESC, s.wins DESC, s.losses ASC
                   FOR XML RAW('rows'), TYPE
            )
            FROM @standings conf_s
           GROUP BY conf_s.conference_key, conf_s.conference_display, conf_s.conference_order
           ORDER BY conf_s.conference_order DESC
             FOR XML RAW('standings'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END
    ELSE -- division
    BEGIN    	
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
                SELECT s.name, s.wins, s.losses, s.ties, s.logo, s.result_effect AS [key]
                  FROM @standings s
                 WHERE s.division_key = div_s.division_key
                 ORDER BY CAST(s.[wins-percentage] AS FLOAT) DESC, s.wins DESC, s.losses ASC
                   FOR XML RAW('rows'), TYPE
            )
            FROM @standings div_s
           GROUP BY div_s.division_key, div_s.division_display, div_s.division_order
           ORDER BY div_s.division_order DESC
             FOR XML RAW('standings'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END
    
    SET NOCOUNT OFF
END

GO
