﻿USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetStandings_Champions_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SMG_GetStandings_Champions_XML]
    @seasonKey INT
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 05/26/2015
  -- Description: get champions standings
  -- Update: 05/27/2015 - John Lin - swap out sprite
  --         06/02/2015 - ikenticus - adding hard-coded league_display for now
  --         10/28/2015 - kkhan - adding comments for editing PR
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @logo_prefix VARCHAR(100) = 'http://www.gannett-cdn.com/media/SMG/sports_logos/'
    DECLARE @logo_folder VARCHAR(100) = '-whitebg/30/'
    DECLARE @logo_suffix VARCHAR(100) = '.png'
    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('champions')

    DECLARE @columns TABLE
    (
        display VARCHAR(100),
        tooltip VARCHAR(100),
        [sort]  VARCHAR(100),
        [type]  VARCHAR(100),
        [column] VARCHAR(100)
    )   
    INSERT INTO @columns (display, tooltip, [sort], [type], [column])
    VALUES ('TEAM', 'Team', '', '', 'team'), ('W', 'Wins', 'desc,asc', 'formatted-num', 'wins'),
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
        division_key VARCHAR(100),
        division_name VARCHAR(100),
        division_order INT,
        -- render
        legend VARCHAR(100),
        logo VARCHAR(100),
        team VARCHAR(100),
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

    INSERT INTO @standings (team_key, [wins], [losses], [ties], [points-scored-for], [points-scored-against], [points])
    SELECT p.team_key, [wins], [losses], [ties], [points-scored-for], [points-scored-against], [points]
      FROM (SELECT team_key, [column], value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.[column] IN ([wins], [losses], [ties], [points-scored-for], [points-scored-against], [points])) AS p

    UPDATE s
       SET s.team = st.team_last,
           s.team_abbr = st.team_abbreviation,
           s.team_slug = st.team_slug,
           s.division_key = sl.division_key,
           s.division_name = sl.division_display,
           s.division_order = sl.division_order
      FROM @standings s
     INNER JOIN dbo.SMG_Teams st
        ON st.team_key = s.team_key AND st.league_key = @league_key AND st.season_key = @seasonKey
     INNER JOIN dbo.SMG_Leagues sl
        On sl.league_key = st.league_key AND sl.season_key = st.season_key AND sl.division_key = st.division_key


    -- render
    UPDATE @standings
       SET legend = '',
           logo = @logo_prefix + 'euro' + @logo_folder + team_abbr + @logo_suffix


    SELECT 'Champions League' AS league_display,
	(
	    SELECT division_name AS ribbon, 'points' AS default_column,
	    (
            SELECT s.legend, s.logo, s.team, [wins], [losses], [ties], [points-scored-for], [points-scored-against], [points]
              FROM @standings s
             WHERE s.division_key = d.division_key
             ORDER BY [points] DESC, [wins] DESC, [points-scored-for] DESC
               FOR XML RAW('row'), TYPE
        )
        FROM @standings d
       GROUP BY division_key, division_name, division_order
       ORDER BY division_order ASC
         FOR XML RAW('table'), TYPE
    ),
    (
        SELECT display, tooltip, [sort], [type], [column]
          FROM @columns
           FOR XML RAW('column'), TYPE
    )
    FOR XML PATH(''), ROOT('root')
    
    SET NOCOUNT OFF
END

GO
