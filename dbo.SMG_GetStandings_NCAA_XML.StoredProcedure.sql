USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetStandings_NCAA_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[SMG_GetStandings_NCAA_XML]
    @leagueKey VARCHAR(100),
    @seasonKey INT,
    @affiliation VARCHAR(100)
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 09/27/2013
  -- Description: get NCAA standings
  -- Update: 01/14/2014 - John Lin - add team slug
  --         10/14/2014 - John Lin - remove league key from SMG_Standings
  --                               - change order
  --         10/22/2014 - ikenticus - use conference percentage when displaying conference standings
  --         05/27/2015 - John Lin - swap out sprite
  --         08/20/2015 - John Lin - SDI migration
  --         09/04/2015 - ikenticus - SDI null-to-zero fixes
  --         10/07/2015 - ikenticus - add losses to the standings ordering
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @logo_prefix VARCHAR(100) = 'http://www.gannett-cdn.com/media/SMG/sports_logos/'
    DECLARE @logo_folder VARCHAR(100) = '-whitebg/30/'
    DECLARE @legend_folder VARCHAR(100) = 'legends/clinched-'
    DECLARE @logo_suffix VARCHAR(100) = '.png'
    DECLARE @ribbon VARCHAR(100) = 'ncaab'
    
    IF (@leagueKey = '/sport/football/league:2')
    BEGIN
        SELECT @ribbon = 'ncaaf'
    END
    
    DECLARE @legend TABLE
    (
        [source] VARCHAR(100),
        [desc] VARCHAR(100)
    )
    INSERT INTO @legend ([source], [desc])
    VALUES (@logo_prefix + @legend_folder + 'z' + @logo_suffix, 'Clinched Conference')

    DECLARE @columns TABLE
    (
        display VARCHAR(100),
        tooltip VARCHAR(100),
        [sort]  VARCHAR(100),
        [type]  VARCHAR(100),
        [column] VARCHAR(100)
    )
    INSERT INTO @columns (display, tooltip, [sort], [type], [column])
    VALUES ('TEAM', 'Team', '', '', 'team'), ('W', 'Wins', 'desc,asc', 'formatted-num', 'wins'), ('L', 'Losses', 'desc,asc', 'formatted-num', 'losses'),
           ('PCT', 'Win-Loss Ratio', 'desc,asc', 'formatted-num', 'wins-percentage'), ('CONF', 'Conference Record', 'desc,asc', 'formatted-num', 'conference-record')

    DECLARE @stats TABLE
    (       
        team_key   VARCHAR(100),
        [column]   VARCHAR(100), 
        value      VARCHAR(100)
    )
    INSERT INTO @stats (team_key, [column], value)
    SELECT team_key, [column], value
      FROM SportsEditDB.dbo.SMG_Standings
     WHERE league_key = @leagueKey AND season_key = @seasonKey

    DECLARE @standings TABLE
    (
		tier INT,
        conference_key VARCHAR(100),
        conference_order INT,
        division_key VARCHAR(100),
        division_order INT,
        division_display VARCHAR(100),
        team_key VARCHAR(100),
        team_abbr VARCHAR(100),
        team_slug VARCHAR(100),
        result_effect VARCHAR(100),
        -- render
        legend VARCHAR(100),
        logo VARCHAR(100),
        team VARCHAR(100),
        link VARCHAR(100),
        wins INT,
        losses INT,
        [wins-percentage] VARCHAR(100),
        [conference-record] VARCHAR(100),
        -- extra
        [away-wins] INT,
        [away-losses] INT,
        [home-wins] INT,
        [home-losses] INT,
        [conference-rank] INT,
        [conference-wins] INT,
        [conference-losses] INT,
        [conference-wins-percentage] VARCHAR(100)
    )
        
    INSERT INTO @standings (team_key, result_effect, [wins], [losses], [away-wins], [away-losses], [home-wins], [home-losses], [conference-wins], [conference-losses], [conference-rank])
    SELECT p.team_key, result_effect, [wins], [losses], ISNULL([away-wins], 0), ISNULL([away-losses], 0),
           ISNULL([home-wins], 0), ISNULL([home-losses], 0), ISNULL([conference-wins], 0), ISNULL([conference-losses], 0), [conference-rank]
      FROM (SELECT team_key, [column], value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.[column] IN (result_effect, [wins], [losses], [away-wins], [away-losses], [home-wins], [home-losses], [conference-wins], [conference-losses], [conference-rank])) AS p

    UPDATE @standings
       SET result_effect = ''
     WHERE result_effect IS NULL

    UPDATE @standings
       SET wins = [away-wins] + [home-wins]
	 WHERE wins IS NULL

    UPDATE @standings
       SET losses = [away-losses] + [home-losses]
	 WHERE losses IS NULL

    UPDATE @standings
       SET [wins-percentage] = CASE
                                   WHEN wins + losses = 0 THEN '.000'
                                   WHEN wins + losses = wins THEN '1.00'
                                   ELSE CAST((CAST(wins AS FLOAT) / (wins + losses)) AS DECIMAL(4, 3))
                               END,
           [conference-wins-percentage] = CASE
                                              WHEN [conference-wins] + [conference-losses] = 0 THEN '.000'
                                              WHEN [conference-wins] + [conference-losses] = [conference-wins] THEN '1.00'
                                              ELSE CAST((CAST([conference-wins] AS FLOAT) / ([conference-wins] + [conference-losses])) AS DECIMAL(4, 3))
                                          END

    UPDATE s
       SET s.conference_key = st.conference_key, s.division_key = st.division_key,
           s.team = st.team_first + ' ' + st.team_last, s.team_abbr = st.team_abbreviation, s.team_slug = st.team_slug
      FROM @standings s
     INNER JOIN dbo.SMG_Teams st
        ON st.league_key = @leagueKey AND st.season_key = @seasonKey AND st.team_key = s.team_key

    UPDATE s
       SET s.tier = sl.tier, s.conference_order = sl.conference_order, s.division_display = sl.division_display, s.division_order = sl.division_order
      FROM @standings s
     INNER JOIN dbo.SMG_Leagues sl
        ON sl.league_key = @leagueKey AND sl.season_key = @seasonKey AND sl.conference_key = s.conference_key AND ISNULL(sl.division_key, '') = ISNULL(s.division_key, '')

	-- Remove non-Div1 teams
	DELETE @standings
	 WHERE tier <> 1 OR tier IS NULL


    -- render
    UPDATE @standings
       SET legend = (CASE
                        WHEN result_effect <> '' THEN @logo_prefix + @legend_folder + result_effect + @logo_suffix
                        ELSE ''
                    END),
           logo = @logo_prefix + 'ncaa' + @logo_folder + team_abbr + @logo_suffix,
           [conference-record] = CAST([conference-wins] AS VARCHAR(100)) + ' - ' + CAST([conference-losses] AS VARCHAR(100))

    IF (@leagueKey = '/sport/football/league:2')
    BEGIN
        UPDATE @standings
           SET link = '/sports/' + @ribbon + '/' + team_slug + '/'
    END
   

    SELECT
    (
        SELECT cd_s.division_display AS ribbon,
        (
            SELECT s.legend, s.logo, s.team, s.link, s.wins, s.losses, s.[conference-record], s.[wins-percentage]
              FROM @standings s
             WHERE s.conference_key = cd_s.conference_key AND ISNULL(s.division_key, '') = ISNULL(cd_s.division_key, '')
             ORDER BY CAST(s.[conference-wins-percentage] AS FLOAT) DESC, s.wins DESC, s.losses ASC, s.[conference-wins] DESC, s.[conference-losses] ASC
               FOR XML RAW('row'), TYPE
        )
        FROM @standings cd_s
       GROUP BY cd_s.conference_key, cd_s.conference_order, cd_s.division_key, cd_s.division_order, cd_s.division_display
       ORDER BY cd_s.conference_order ASC, cd_s.division_order ASC
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
    
    SET NOCOUNT OFF
END 

GO
