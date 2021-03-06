USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[MOB_GetStandings_NFL_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[MOB_GetStandings_NFL_XML]
    @seasonKey INT,
    @affiliation VARCHAR(100)
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 01/07/2014
  -- Description: get NFL standings for moblie
  -- Update: 10/14/2014 - John Lin - remove league key from SMG_Standings
  --         12/19/2014 - John Lin - whitebg
  --         07/01/2015 - ikenticus - utilize conf/div rank from STATS when available
  --         08/05/2015 - John Lin - SDI migration
  --         09/14/2015 - John Lin - default null to zero
  --         10/12/2015 - John Lin - additional sort
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('nfl')

    DECLARE @standings TABLE
    (
        conference_key VARCHAR(100),
        conference_display VARCHAR(100),
        conference_oder INT,
        division_key VARCHAR(100),
        division_display VARCHAR(100),
        division_order INT,
        team_key VARCHAR(100),
        -- render
        team_abbreviation VARCHAR(100),
        long_display VARCHAR(100),
        wins INT,
        losses INT,
        ties INT,
        winning_percentage VARCHAR(100),
        team_page VARCHAR(100),
        result_effect VARCHAR(100),
        logo VARCHAR(100),
        -- extra
        [away-wins] INT,
        [away-losses] INT,
        [away-ties] INT,
        [home-wins] INT,
        [home-losses] INT,
        [home-ties] INT
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
     WHERE ss.season_key = @seasonKey

    INSERT INTO @standings (team_key, result_effect, [away-wins], [away-losses], [away-ties], [home-wins], [home-losses], [home-ties])
    SELECT p.team_key, result_effect, ISNULL([away-wins], 0), ISNULL([away-losses], 0), ISNULL([away-ties], 0),
           ISNULL([home-wins], 0), ISNULL([home-losses], 0), ISNULL([home-ties], 0)
      FROM (SELECT team_key, [column], value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.[column] IN (result_effect, [away-wins], [away-losses], [away-ties], [home-wins], [home-losses], [home-ties])) AS p

    UPDATE @standings
       SET wins = [away-wins] + [home-wins],
           losses = [away-losses] + [home-losses],
           ties = [away-ties] + [home-ties]

    UPDATE @standings
       SET winning_percentage = CASE
                                    WHEN wins + losses + ties = 0 THEN '.000'
                                    WHEN wins + losses + ties = wins THEN '1.00'
                                    ELSE REPLACE(CAST((CAST(wins + (ties * 0.5) AS FLOAT) / (wins + losses + ties)) AS DECIMAL(4, 3)), '0.', '.')
                                END

    UPDATE s
       SET s.conference_key = sl.conference_key,
           s.conference_display = sl.conference_display,
           s.conference_oder = sl.conference_order,
           s.division_key = sl.division_key,
           s.division_display = sl.division_display,
           s.division_order = sl.division_order,
           s.long_display = st.team_first + ' ' + st.team_last,
           s.team_abbreviation = st.team_abbreviation,
           s.team_page = 'http://www.usatoday.com/sports/nfl/' + st.team_slug
      FROM @standings s
     INNER JOIN dbo.SMG_Teams st
        ON st.team_key = s.team_key AND st.league_key = @league_key AND st.season_key = @seasonKey
     INNER JOIN dbo.SMG_Leagues sl
        On sl.league_key = st.league_key AND sl.season_key = st.season_key AND sl.conference_key = st.conference_key AND sl.division_key = st.division_key


    -- render
    UPDATE @standings
       SET result_effect = ''
     WHERE result_effect IS NULL

    UPDATE @standings
       SET logo = dbo.SMG_fnTeamLogo('nfl', team_abbreviation, '22')


    IF (@affiliation = 'conference')
    BEGIN
        SELECT
	    (
            SELECT conf_s.conference_display AS ribbon,
            (
                SELECT s.team_abbreviation AS short_display, s.long_display, s.wins, s.losses, s.ties, s.winning_percentage,
                       s.team_page, s.result_effect AS legend_key, logo
                  FROM @standings s
                 WHERE s.conference_key = conf_s.conference_key
                 ORDER BY CAST(s.winning_percentage AS FLOAT) DESC, s.wins DESC, s.losses ASC
                   FOR XML RAW('teams'), TYPE
            )
            FROM @standings conf_s
           GROUP BY conf_s.conference_key, conf_s.conference_display, conf_s.conference_oder
           ORDER BY conf_s.conference_oder ASC
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
        SELECT
	    (
	        SELECT 'NFL' AS ribbon,
	        (
                SELECT s.team_abbreviation AS short_display, s.long_display, s.wins, s.losses, s.ties, s.winning_percentage,
                       s.team_page, s.result_effect AS legend_key, logo
                  FROM @standings s
                 ORDER BY CAST(s.winning_percentage AS FLOAT) DESC, s.wins DESC, s.losses ASC
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
    ELSE -- division
    BEGIN    	
        SELECT
	    (
            SELECT div_s.division_display AS ribbon,
            (
                SELECT s.team_abbreviation AS short_display, s.long_display, s.wins, s.losses, s.ties, s.winning_percentage,
                       s.team_page, s.result_effect AS legend_key, logo
                  FROM @standings s
                 WHERE s.division_key = div_s.division_key
                 ORDER BY CAST(s.winning_percentage AS FLOAT) DESC, s.wins DESC, s.losses ASC
                   FOR XML RAW('teams'), TYPE
            )
            FROM @standings div_s
           GROUP BY div_s.division_key, div_s.division_display, div_s.division_order
           ORDER BY div_s.division_order ASC
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
