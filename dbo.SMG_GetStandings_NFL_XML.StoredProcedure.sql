USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetStandings_NFL_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[SMG_GetStandings_NFL_XML]
    @seasonKey INT,
    @affiliation VARCHAR(100)
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 09/27/2013
  -- Description: get NFL standings
  -- Update: 01/14/2014 - John Lin - add team slug
  --         10/14/2014 - John Lin - remove league key from SMG_Standings
  --         05/27/2015 - John Lin - swap out sprite
  --         06/30/2015 - John Lin - STATS migration
  --         07/01/2015 - ikenticus - utilize conf/div rank from STATS when available
  --         08/08/2015 - John Lin - SDI migration
  --         09/14/2015 - John Lin - default null to zero
  --         10/12/2015 - John Lin - additional sort
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('nfl')
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
    VALUES (@logo_prefix + @legend_folder + 'w' + @logo_suffix, 'Clinched Wild Card'),
           (@logo_prefix + @legend_folder + 'y' + @logo_suffix, 'Clinched Division'),
           (@logo_prefix + @legend_folder + 'x' + @logo_suffix, 'Clinched Playoff Berth'),
           (@logo_prefix + @legend_folder + 's' + @logo_suffix, 'Clinched Division & Home Field')

    DECLARE @columns TABLE
    (
        display VARCHAR(100),
        tooltip VARCHAR(100),
        [sort]  VARCHAR(100),
        [type]  VARCHAR(100),
        [column] VARCHAR(100)
    )   
    INSERT INTO @columns (display, tooltip, [sort], [type], [column])
    VALUES ('TEAM', 'Team', '', '', 'team'), ('W', 'Wins', 'desc,asc', 'formatted-num', 'wins'), ('L', 'Losses', 'asc,desc', 'formatted-num', 'losses'),
           ('T', 'Ties', 'desc,asc', 'formatted-num', 'ties'), ('PCT', 'Win-Loss Ratio', 'desc,asc', 'formatted-num', 'wins-percentage'),
           ('HOME', 'Home Record', 'desc,asc', 'formatted-num', 'home_record'), ('ROAD', 'Away Record', 'desc,asc', 'formatted-num', 'away_record'),
           ('DIV', 'Division Record', 'desc,asc', 'formatted-num', 'division_record'),
           ('CONF', 'Conference Record', 'desc,asc', 'formatted-num', 'conference_record'),
           ('PF', 'Points Scored For', 'desc,asc', 'formatted-num', 'points-scored-for'),
           ('PA', 'Points Scored Against', 'desc,asc', 'formatted-num', 'points-scored-against'),
           ('DIFF', 'Points Differential', 'desc,asc', 'formatted-num', 'points_differential')

    DECLARE @stats TABLE
    (
        team_key   VARCHAR(100),
        [column]   VARCHAR(100), 
        value      VARCHAR(100)
    )
    INSERT INTO @stats (team_key, [column], value)
    SELECT team_key, [column], value
      FROM SportsEditDB.dbo.SMG_Standings
     WHERE league_key = @league_key AND season_key = @seasonKey

    DECLARE @standings TABLE
    (
        conference_key VARCHAR(100),
        conference_display VARCHAR(100),
        conference_order INT,
        division_key VARCHAR(100),
        division_display VARCHAR(100),
        division_order INT,
        team_key VARCHAR(100),
        team_abbr VARCHAR(100),
        team_slug VARCHAR(100),
        result_effect VARCHAR(100),
        [away-wins] INT,
        [away-losses] INT,
        [away-ties] INT,
        [home-wins] INT,
        [home-losses] INT,
        [home-ties] INT,
        [division-wins] INT,
        [division-losses] INT,
        [division-ties] INT,
        [conference-wins] INT,
        [conference-losses] INT,
        [conference-ties] INT,
        -- render
        legend VARCHAR(100),
        logo VARCHAR(100),
        team VARCHAR(100),
        link VARCHAR(100),
        wins INT,
        losses INT,
        ties INT,
        [wins-percentage] VARCHAR(100),
        home_record VARCHAR(100),
        away_record VARCHAR(100),
        division_record VARCHAR(100),
        conference_record VARCHAR(100),
        [points-scored-for] INT,
        [points-scored-against] INT,
        points_differential VARCHAR(100)
    )

            
    INSERT INTO @standings (team_key, [away-wins], [away-losses], [away-ties], [home-wins], [home-losses], [home-ties],
                            [division-wins], [division-losses], [division-ties], [conference-wins], [conference-losses], [conference-ties],
                            [points-scored-for], [points-scored-against], result_effect)
    SELECT p.team_key, ISNULL([away-wins], 0), ISNULL([away-losses], 0), ISNULL([away-ties], 0),
           ISNULL([home-wins], 0), ISNULL([home-losses], 0), ISNULL([home-ties], 0),
           ISNULL([division-wins], 0), ISNULL([division-losses], 0), ISNULL([division-ties], 0),
           ISNULL([conference-wins], 0), ISNULL([conference-losses], 0), ISNULL([conference-ties], 0), 
           CAST([points-scored-for] AS INT), CAST([points-scored-against] AS INT), [result-effect]
      FROM (SELECT team_key, [column], value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.[column] IN ([away-wins], [away-losses], [away-ties], [home-wins], [home-losses], [home-ties],
                                            [division-wins], [division-losses], [division-ties], [conference-wins], [conference-losses], [conference-ties],
                                            [points-scored-for], [points-scored-against], [result-effect])) AS p

    UPDATE @standings
       SET wins = [away-wins] + [home-wins],
           losses = [away-losses] + [home-losses],
           ties = [away-ties] + [home-ties]

    UPDATE @standings
       SET [wins-percentage] = CASE
                                   WHEN wins + losses + ties = wins THEN '1.00'
                                   ELSE CAST((CAST(wins + (ties * 0.5) AS FLOAT) / (wins + losses + ties)) AS DECIMAL(4, 2))
                               END

    UPDATE @standings
       SET result_effect = ''
     WHERE result_effect IS NULL
    
    UPDATE s
       SET s.conference_key = st.conference_key,
           s.division_key =  st.division_key,
           s.team = st.team_first + ' ' + st.team_last,
           s.team_abbr = st.team_abbreviation,
           s.team_slug = st.team_slug
      FROM @standings s
     INNER JOIN dbo.SMG_Teams st
        ON st.league_key = @league_key AND st.season_key = @seasonKey AND st.team_key = s.team_key

    UPDATE s
       SET s.conference_display = sl.conference_display, s.conference_order = sl.conference_order,
           s.division_display = sl.division_display, s.division_order = sl.division_order
      FROM @standings s
     INNER JOIN dbo.SMG_Leagues sl
        ON sl.league_key = @league_key AND sl.season_key = @seasonKey AND sl.conference_key = s.conference_key AND sl.division_key = s.division_key

    -- render
    UPDATE @standings
       SET legend = (CASE
                        WHEN result_effect <> '' THEN @logo_prefix + @legend_folder + result_effect + @logo_suffix
                        ELSE ''
                    END),
           logo = @logo_prefix + 'nfl' + @logo_folder + team_abbr + @logo_suffix,
           link = '/sports/nfl/' + team_slug + '/',
           home_record = CAST([home-wins] AS VARCHAR(100)) + '-' + CAST([home-losses] AS VARCHAR(100)) + '-' + CAST([home-ties] AS VARCHAR(100)),
           away_record = CAST([away-wins] AS VARCHAR(100)) + '-' + CAST([away-losses] AS VARCHAR(100)) + '-' + CAST([away-ties] AS VARCHAR(100)),
           division_record = CAST([division-wins] AS VARCHAR(100)) + '-' + CAST([division-losses] AS VARCHAR(100)) + '-' + CAST([division-ties] AS VARCHAR(100)),
           conference_record = CAST([conference-wins] AS VARCHAR(100)) + '-' + CAST([conference-losses] AS VARCHAR(100)) + '-' + CAST([conference-ties] AS VARCHAR(100)),
           points_differential = (CASE
                                   WHEN [points-scored-for] > [points-scored-against] THEN '+' + CAST(([points-scored-for] - [points-scored-against]) AS VARCHAR(100))
                                   WHEN [points-scored-against] > [points-scored-for] THEN '-' + CAST(([points-scored-against] - [points-scored-for]) AS VARCHAR(100))
                                   ELSE '0'
                               END)


    IF (@affiliation = 'conference')
    BEGIN
        SELECT
	    (
            SELECT conf_s.conference_display AS ribbon, 'win_loss_ratio' AS default_column,
            (
                SELECT s.legend, s.logo, s.team, s.link, s.wins, s.losses, s.ties, s.[wins-percentage], s.home_record, s.away_record, s.division_record,
                       s.conference_record, s.[points-scored-for], s.[points-scored-against], s.points_differential                       
                  FROM @standings s
                 WHERE s.conference_key = conf_s.conference_key
                 ORDER BY CAST(s.[wins-percentage] AS FLOAT) DESC, s.wins DESC, s.losses ASC
                   FOR XML RAW('row'), TYPE
            )
            FROM @standings conf_s
           GROUP BY conf_s.conference_key, conf_s.conference_display, conf_s.conference_order
           ORDER BY conf_s.conference_order
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
    ELSE IF (@affiliation = 'division')
    BEGIN    	
        SELECT
	    (
            SELECT div_s.division_display AS ribbon, 'win_loss_ratio' AS default_column,
            (
                SELECT s.legend, s.logo, s.team, s.link, s.wins, s.losses, s.ties, s.[wins-percentage], s.home_record, s.away_record, s.division_record,
                       s.conference_record, s.[points-scored-for], s.[points-scored-against], s.points_differential                       
                  FROM @standings s
                 WHERE s.division_key = div_s.division_key
                 ORDER BY CAST(s.[wins-percentage] AS FLOAT) DESC, s.wins DESC, s.losses ASC
                   FOR XML RAW('row'), TYPE
            )
            FROM @standings div_s
           GROUP BY div_s.division_key, div_s.division_display, div_s.division_order
           ORDER BY div_s.division_order
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
    ELSE
    BEGIN
        SELECT
	    (
	        SELECT 'NFL' AS ribbon, 'win_loss_ratio' AS default_column,
	        (
                SELECT s.legend, s.logo, s.team, s.link, s.wins, s.losses, s.ties, s.[wins-percentage], s.home_record, s.away_record, s.division_record,
                       s.conference_record, s.[points-scored-for], s.[points-scored-against], s.points_differential                       
                  FROM @standings s
                 ORDER BY CAST(s.[wins-percentage] AS FLOAT) DESC, s.wins DESC, s.losses ASC
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
    
    SET NOCOUNT OFF
END

GO
