USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetTeamDivision_NCAA_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SMG_GetTeamDivision_NCAA_XML]
    @leagueName  VARCHAR(100),
    @teamSlug    VARCHAR(100)
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 01/16/2014
  -- Description: get ncaa division standings by team slug's division
  -- Update:      02/20/2014 - use latest year of standings table
  --              10/14/2014 - John Lin - remove league key from SMG_Standings
  --              10/22/2014 - ikenticus - switching to conference-winning-percentage
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100)
    DECLARE @season_key INT
    DECLARE @conference_key VARCHAR(100)
    
	SELECT @league_key = league_display_name
	  FROM sportsDB.dbo.USAT_leagues
     WHERE league_name = LOWER(@leagueName)

    SELECT TOP 1 @season_key = season_key
      FROM SportsEditDB.dbo.SMG_Standings
     WHERE LEFT(team_key, LEN(@league_key)) = @league_key
     ORDER BY season_key DESC

    SELECT @conference_key = conference_key
      FROM dbo.SMG_Teams
     WHERE league_key = @league_key AND season_key = @season_key AND team_slug = @teamSlug          

    DECLARE @columns TABLE
    (
        display      VARCHAR(100),
        [column]     VARCHAR(100),
        division_key VARCHAR(100),
        [order]      INT
    )
     
    DECLARE @standings TABLE
    (
        team_key VARCHAR(100),
        team_first VARCHAR(100),
        team_last VARCHAR(100),
        team_abbreviation VARCHAR(100),
        team_slug VARCHAR(100),
        -- ncaa    
        division_key VARCHAR(100),
        division_order VARCHAR(100),
        division_display VARCHAR(100),
        conference_wins VARCHAR(100),
        conference_losses VARCHAR(100),
        conference VARCHAR(100),
        -- render
        team VARCHAR(100),
        [wins] INT,
        [losses] INT,
        [winning_percentage] VARCHAR(100),
        [conference_winning_percentage] VARCHAR(100)
    )
    
    INSERT INTO @standings (division_key, team_key, team_first, team_last, team_abbreviation, team_slug, [wins], [losses])
    SELECT division_key, team_key, team_first, team_last, team_abbreviation, team_slug, 0, 0
      FROM dbo.SMG_Teams
     WHERE league_key = @league_key AND season_key = @season_key AND conference_key = @conference_key

    UPDATE s
       SET s.[wins] = CAST(ss.value AS INT)
      FROM @standings s
     INNER JOIN SportsEditDB.dbo.SMG_Standings ss
        ON ss.season_key = @season_key AND ss.team_key = s.team_key AND ss.[column] = 'wins'

    UPDATE s
       SET s.[losses] = CAST(ss.value AS INT)
      FROM @standings s
     INNER JOIN SportsEditDB.dbo.SMG_Standings ss
        ON ss.season_key = @season_key AND ss.team_key = s.team_key AND ss.[column] = 'losses'

    UPDATE s
       SET s.[winning_percentage] = ss.value
      FROM @standings s
     INNER JOIN SportsEditDB.dbo.SMG_Standings ss
        ON ss.season_key = @season_key AND ss.team_key = s.team_key AND ss.[column] = 'winning-percentage'    

    UPDATE s
       SET s.[conference_winning_percentage] = ss.value
      FROM @standings s
     INNER JOIN SportsEditDB.dbo.SMG_Standings ss
        ON ss.season_key = @season_key AND ss.team_key = s.team_key AND ss.[column] = 'conference-winning-percentage'    
        
    UPDATE s
       SET s.conference_wins = ss.value
      FROM @standings s
     INNER JOIN SportsEditDB.dbo.SMG_Standings ss
        ON ss.season_key = @season_key AND ss.team_key = s.team_key AND ss.[column] = 'conference-wins'

    UPDATE s
       SET s.conference_losses = ss.value
      FROM @standings s
     INNER JOIN SportsEditDB.dbo.SMG_Standings ss
        ON ss.season_key = @season_key AND ss.team_key = s.team_key AND ss.[column] = 'conference-losses'


    UPDATE @standings
       SET winning_percentage = '.000'
     WHERE winning_percentage IS NULL

    UPDATE s
       SET s.division_order = sl.division_order, s.division_display = sl.division_display
      FROM @standings s
     INNER JOIN dbo.SMG_Leagues sl
        ON sl.league_key = @league_key AND sl.season_key = @season_key AND sl.conference_key = @conference_key AND sl.division_key = s.division_key
              
    UPDATE @standings
       SET team = team_abbreviation + '|' + team_first + ' ' + team_last + '|' + team_slug,
           conference = conference_wins + '-' + conference_losses


    INSERT INTO @columns (display, [column], division_key, [order])
    SELECT division_display, 'team', division_key, 1
      FROM @standings
     GROUP BY division_display, division_key

    INSERT INTO @columns (display, [column], division_key, [order])
    SELECT 'W', 'wins', division_key, 2
      FROM @standings
     GROUP BY division_display, division_key

    INSERT INTO @columns (display, [column], division_key, [order])
    SELECT 'L', 'losses', division_key, 3
      FROM @standings
     GROUP BY division_display, division_key

    INSERT INTO @columns (display, [column], division_key, [order])
    SELECT 'PCT', 'winning_percentage', division_key, 4
      FROM @standings
     GROUP BY division_display, division_key

    INSERT INTO @columns (display, [column], division_key, [order])
    SELECT 'CONF', 'conference', division_key, 5
      FROM @standings
     GROUP BY division_display, division_key


    SELECT
    (
        
        SELECT 
        (
            SELECT s.team, s.[wins], s.[losses], s.[winning_percentage], s.conference
              FROM @standings s
             WHERE s.division_key = cd_s.division_key
             ORDER BY CAST(s.conference_winning_percentage AS FLOAT) DESC, CAST(s.conference_wins AS INT) DESC, CAST(s.conference_losses AS INT) ASC
               FOR XML RAW('team'), TYPE
        ),
        (
            SELECT display, [column]
              FROM @columns c
             WHERE c.division_key = cd_s.division_key
             ORDER BY c.[order] ASC
               FOR XML RAW('column'), TYPE
        )        
        FROM @standings cd_s
       GROUP BY cd_s.division_key, cd_s.division_order
       ORDER BY cd_s.division_order ASC
         FOR XML RAW('conference'), TYPE
    )
    FOR XML PATH(''), ROOT('root')

    SET NOCOUNT OFF
END 

GO
