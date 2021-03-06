USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetStandings_EPL_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SMG_GetStandings_EPL_XML]
    @seasonKey INT
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 05/26/2015
  -- Description: get EPL standings
  -- Update: 05/27/2015 - John Lin - swap out sprite
  --         06/02/2015 - ikenticus - adding hard-coded league_display for now
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @logo_prefix VARCHAR(100) = 'http://www.gannett-cdn.com/media/SMG/sports_logos/'
    DECLARE @logo_folder VARCHAR(100) = '-whitebg/30/'
    DECLARE @legend_folder VARCHAR(100) = 'legends/clinched-'
    DECLARE @logo_suffix VARCHAR(100) = '.png'
    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('epl')

    DECLARE @legend TABLE
    (
        [source] VARCHAR(100),
        [desc] VARCHAR(100)
    )
    INSERT INTO @legend ([source], [desc])
    VALUES (@logo_prefix + @legend_folder + 'c' + @logo_suffix, 'Champions League'),
           (@logo_prefix + @legend_folder + 'e' + @logo_suffix, 'Europa League'),
           (@logo_prefix + @legend_folder + 'r' + @logo_suffix, 'Relegation')
              
    DECLARE @columns TABLE
    (
        display VARCHAR(100),
        tooltip VARCHAR(100),
        [sort]  VARCHAR(100),
        [type]  VARCHAR(100),
        [column] VARCHAR(100)
    )   
    INSERT INTO @columns (display, tooltip, [sort], [type], [column])
    VALUES ('TEAM', 'Team', '', '', 'team'), ('POS', 'Position', 'asc,desc', 'formatted-num', 'position'),
           ('GP', 'Played', 'desc,asc', 'formatted-num', 'events-played'), ('W', 'Wins', 'desc,asc', 'formatted-num', 'wins'),
           ('L', 'Losses', 'asc,desc', 'formatted-num', 'losses'), ('T', 'Ties', 'desc,asc', 'formatted-num', 'ties'),
           ('GF', 'Goals For', 'desc,asc', 'formatted-num', 'points-scored-for'),
           ('GA', 'Goals Against', 'desc,asc', 'formatted-num', 'points-scored-against'),
           ('PTS', 'Standings Points', 'desc,asc', 'formatted-num', 'points')

    DECLARE @standings TABLE
    (
        team_key VARCHAR(100),
        team_abbr VARCHAR(100),
        team_slug VARCHAR(100),
        result_effect VARCHAR(100),
        -- render
        legend VARCHAR(100),
        logo VARCHAR(100),
        team VARCHAR(100),
        [rank] VARCHAR(100),
        [position] INT,
        [events-played] INT,
        [wins] INT,
        [losses] INT,
        [ties] INT,
        [points-scored-for] INT,
        [points-scored-against] INT,
        [points] INT
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

    INSERT INTO @standings (team_key, [rank], [position], [events-played], [wins], [losses], [ties], [points-scored-for], [points-scored-against], [points])
    SELECT p.team_key, [rank], [position], [events-played], [wins], [losses], [ties], [points-scored-for], [points-scored-against], [points]
      FROM (SELECT team_key, [column], value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.[column] IN ([rank], [position], [events-played], [wins], [losses], [ties], [points-scored-for], [points-scored-against], [points])) AS p

    UPDATE s
       SET s.team = st.team_last,
           s.team_abbr = st.team_abbreviation,
           s.team_slug = st.team_slug
      FROM @standings s
     INNER JOIN dbo.SMG_Teams st
        ON st.team_key = s.team_key AND st.league_key = @league_key AND st.season_key = @seasonKey

	-- add keys
	DECLARE @last_position INT

	SELECT @last_position = MAX(position)
	  FROM @standings

	UPDATE @standings
	   SET result_effect = 'c'
	 WHERE position BETWEEN 1 AND 4

	UPDATE @standings
	   SET result_effect = 'e'
	 WHERE position BETWEEN 5 AND 6

	UPDATE @standings
	   SET result_effect = 'r'
	 WHERE position >= @last_position - 2

    -- render
    UPDATE @standings
       SET legend = (CASE
                        WHEN result_effect <> '' THEN @logo_prefix + @legend_folder + result_effect + @logo_suffix
                        ELSE ''
                    END),
           logo = @logo_prefix + 'euro' + @logo_folder + team_abbr + @logo_suffix



    SELECT 'EPL' AS league_display,
	(
	    SELECT 'EPL' AS ribbon, 'points' AS default_column,
	    (
            SELECT legend, logo, team, [position], [events-played], [wins], [losses], [ties], [points-scored-for], [points-scored-against], [points]
              FROM @standings
             ORDER BY [position] ASC
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
    
    SET NOCOUNT OFF
END

GO
