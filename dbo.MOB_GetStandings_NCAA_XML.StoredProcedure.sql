USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[MOB_GetStandings_NCAA_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[MOB_GetStandings_NCAA_XML]
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @affiliation VARCHAR(100)
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 01/07/2014
  -- Description: get NCAA standings for mobile
  --              09/03/2014 - ikenticus - switching NCAA logos to whitebg per JIRA SMW-91
  --              10/14/2014 - John Lin - remove league key from SMG_Standings
  --                                    - change order
  --              10/23/2014 - John Lin - change order
  --              10/19/2015 - John Lin - remove non Div I teams
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    
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
        tier INT,
        conference_key VARCHAR(100),
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
        conference_record VARCHAR(100),
        team_page VARCHAR(100),
        result_effect VARCHAR(100),
        logo VARCHAR(100),
        -- extra
        [away-wins] INT,
        [away-losses] INT,
        [home-wins] INT,
        [home-losses] INT,
        [conference-wins] INT,
        [conference-losses] INT,
        [conference-wins-percentage] VARCHAR(100)
    )
    INSERT INTO @standings (team_key, result_effect, [away-wins], [away-losses], [home-wins], [home-losses], [conference-wins], [conference-losses])
    SELECT p.team_key, [result-effect], ISNULL([away-wins], 0), ISNULL([away-losses], 0), ISNULL([home-wins], 0), ISNULL([home-losses], 0),
           ISNULL([conference-wins], 0), ISNULL([conference-losses], 0)
      FROM (SELECT team_key, [column], value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.[column] IN ([result-effect], [away-wins], [away-losses], [home-wins], [home-losses], [conference-wins], [conference-losses])) AS p

    UPDATE @standings
       SET result_effect = ''
     WHERE result_effect IS NULL

    UPDATE @standings
       SET wins = [away-wins] + [home-wins],
           losses = [away-losses] + [home-losses]

    UPDATE @standings
       SET winning_percentage = CASE
                                   WHEN wins + losses = 0 THEN '.000'
                                   WHEN wins + losses = wins THEN '1.00'
                                   ELSE CAST((CAST(wins AS FLOAT) / (wins + losses)) AS DECIMAL(4, 3))
                               END,
           [conference-wins-percentage] = CASE
                                            WHEN [conference-wins] + [conference-losses] = 0 THEN '.000'
                                            WHEN [conference-wins] + [conference-losses] = [conference-wins] THEN '1.00'
                                            ELSE CAST((CAST([conference-wins] AS FLOAT) / ([conference-wins] + [conference-losses])) AS DECIMAL(4, 3))
                                        END,
           conference_record = CAST([conference-wins] AS VARCHAR) + '-' + CAST([conference-losses] AS VARCHAR)
           
    UPDATE @standings
       SET winning_percentage = REPLACE(winning_percentage, '0.', '.'),
           [conference-wins-percentage] = REPLACE([conference-wins-percentage], '0.', '.')
               
    UPDATE s
       SET s.conference_key = st.conference_key, s.division_key = st.division_key,
           s.long_name = st.team_first + ' ' + st.team_last, s.team_abbreviation = st.team_abbreviation,
           s.team_page = 'http://www.usatoday.com/sports/' + @leagueName + '/' + st.team_slug,
           s.logo = 'http://www.gannett-cdn.com/media/SMG/sports_logos/ncaa-whitebg/22/' + st.team_abbreviation + '.png' 
      FROM @standings s
     INNER JOIN dbo.SMG_Teams st
        ON st.league_key = @league_key AND st.season_key = @seasonKey AND st.team_key = s.team_key

    UPDATE s
       SET s.tier = sl.tier, s.conference_order =  sl.conference_order, s.division_display =  sl.division_display
      FROM @standings s
     INNER JOIN dbo.SMG_Leagues sl
        On sl.league_key = @league_key AND sl.season_key = @seasonKey AND sl.conference_key = s.conference_key AND ISNULL(sl.division_key, '') = ISNULL(s.division_key, '')
        
	-- Remove non-Div1 teams
	DELETE @standings
	 WHERE tier <> 1 OR tier IS NULL



    SELECT
    (
        SELECT cd_s.division_display AS ribbon,
        (
            SELECT s.team_abbreviation AS short_name, s.long_name, s.wins, s.losses, s.winning_percentage, s.conference_record,
                   s.team_page, s.result_effect AS legend_key, logo
              FROM @standings s
             WHERE s.conference_key = cd_s.conference_key AND ISNULL(s.division_key, '') = ISNULL(cd_s.division_key, '')
             ORDER BY CAST(s.[conference-wins-percentage] AS FLOAT) DESC, s.wins DESC, s.losses ASC, s.[conference-wins] DESC, s.[conference-losses] ASC
               FOR XML RAW('teams'), TYPE
        )
        FROM @standings cd_s
       GROUP BY cd_s.conference_key, cd_s.conference_order, cd_s.division_key, cd_s.division_display, cd_s.division_order
       ORDER BY cd_s.conference_order ASC, cd_s.division_order ASC
         FOR XML RAW('standings'), TYPE
    ),
    (
        SELECT @seasonKey AS [year], @affiliation AS affiliation
           FOR XML RAW('defaults'), TYPE
    )
    FOR XML PATH(''), ROOT('root')
    
    SET NOCOUNT OFF
END 

GO
