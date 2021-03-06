USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetTeamDivision_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[SMG_GetTeamDivision_XML]
    @leagueName  VARCHAR(100),
    @teamSlug    VARCHAR(100)
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 01/16/2014
  -- Description: get division standings by team slug's division
  -- Update:      02/20/2014 - use latest year of standings table
  --              10/14/2014 - John Lin - remove league key from SMG_Standings
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    IF (@leagueName IN ('ncaaf', 'ncaab', 'ncaaw'))
    BEGIN
        EXEC dbo.SMG_GetTeamDivision_NCAA_XML @leagueName, @teamSlug
        RETURN
    END


    DECLARE @league_key VARCHAR(100)
    DECLARE @season_key INT
    DECLARE @conference_key VARCHAR(100)
    DECLARE @division_key VARCHAR(100)
    
	SELECT @league_key = league_display_name
	  FROM sportsDB.dbo.USAT_leagues
     WHERE league_name = LOWER(@leagueName)

    SELECT TOP 1 @season_key = season_key
      FROM SportsEditDB.dbo.SMG_Standings
     WHERE LEFT(team_key, LEN(@league_key)) = @league_key
     ORDER BY season_key DESC

    SELECT @conference_key = conference_key, @division_key = division_key
      FROM dbo.SMG_Teams
     WHERE league_key = @league_key AND season_key = @season_key AND team_slug = @teamSlug          

    DECLARE @columns TABLE
    (
        display VARCHAR(100),
        [column] VARCHAR(100)
    )
     
    DECLARE @standings TABLE
    (
        team_key VARCHAR(100),
        team_first VARCHAR(100),
        team_last VARCHAR(100),
        team_abbreviation VARCHAR(100),
        team_slug VARCHAR(100),
        -- render
        team VARCHAR(100),
        [wins] INT,
        [losses] INT,
        [ties] INT, -- NFL
        [winning_percentage] VARCHAR(100), -- MLB, NBA, NFL, WNBA
        [games_back] VARCHAR(100), -- MLB, NBA, WNBA
        [overtime_losses] VARCHAR(100), -- NHL
        [standings_points] VARCHAR(100) -- NHL
    )
    
    INSERT INTO @standings (team_key, team_first, team_last, team_abbreviation, team_slug, [wins], [losses])
    SELECT team_key, team_first, team_last, team_abbreviation, team_slug, 0, 0
      FROM dbo.SMG_Teams
     WHERE league_key = @league_key AND season_key = @season_key AND conference_key = @conference_key AND division_key = @division_key

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

    
    INSERT INTO @columns (display, [column])
    VALUES ('TEAM', 'team'), ('W', 'wins'), ('L', 'losses')
           
    IF (@league_key IN ('l.nfl.com', 'l.mlsnet.com'))
    BEGIN
        INSERT INTO @columns (display, [column])
        VALUES ('T', 'ties')
        
        UPDATE s
           SET s.[ties] = CAST(ss.value AS INT)
          FROM @standings s
         INNER JOIN SportsEditDB.dbo.SMG_Standings ss
            ON ss.season_key = @season_key AND ss.team_key = s.team_key AND ss.[column] = 'ties'
            
        UPDATE @standings
           SET ties = 0
         WHERE ties IS NULL
    END

    IF (@league_key IN ('l.mlb.com', 'l.nba.com', 'l.nfl.com', 'l.wnba.com'))
    BEGIN
        INSERT INTO @columns (display, [column])
        VALUES ('PCT', 'winning_percentage')
        
        UPDATE s
           SET s.[winning_percentage] = ss.value
          FROM @standings s
         INNER JOIN SportsEditDB.dbo.SMG_Standings ss
            ON ss.season_key = @season_key AND ss.team_key = s.team_key AND ss.[column] = 'winning-percentage'

        UPDATE @standings
           SET winning_percentage = '.000'
         WHERE winning_percentage IS NULL
    END
    
    IF (@league_key IN ('l.mlb.com', 'l.nba.com', 'l.wnba.com'))
    BEGIN
        INSERT INTO @columns (display, [column])
        VALUES ('GB', 'games_back')
        
        UPDATE s
           SET s.[games_back] = ss.value
          FROM @standings s
         INNER JOIN SportsEditDB.dbo.SMG_Standings ss
            ON ss.season_key = @season_key AND ss.team_key = s.team_key AND ss.[column] = 'games-back'

        UPDATE @standings
           SET [games_back] = '0'
         WHERE [games_back] IS NULL
         
        UPDATE @standings
           SET [games_back] = REPLACE(REPLACE(REPLACE([games_back], '1/2', '.5'), '.0', ''), ' ', '')
    END

    IF (@league_key IN ('l.nhl.com', 'l.mlsnet.com'))
    BEGIN
        INSERT INTO @columns (display, [column])
        VALUES ('PTS', 'standings_points')
        
        UPDATE s
           SET s.[standings_points] = ss.value
          FROM @standings s
         INNER JOIN SportsEditDB.dbo.SMG_Standings ss
            ON ss.season_key = @season_key AND ss.team_key = s.team_key AND ss.[column] = 'standing-points'

        UPDATE @standings
           SET [standings_points] = '0'
         WHERE [standings_points] IS NULL            
    END

    IF (@league_key = 'l.nhl.com')
    BEGIN    
        INSERT INTO @columns (display, [column])
        VALUES ('OTL', 'overtime_losses')
        
        UPDATE s
           SET s.[overtime_losses] = ss.value
          FROM @standings s
         INNER JOIN SportsEditDB.dbo.SMG_Standings ss
            ON ss.season_key = @season_key AND ss.team_key = s.team_key AND ss.[column] = 'overtime-losses'

        UPDATE @standings
           SET [overtime_losses] = '0'
         WHERE [overtime_losses] IS NULL
    END

    UPDATE @standings
       SET team = @leagueName + REPLACE(team_key, @league_key + '-t.', '') + '|' + team_first + ' ' + team_last + '|' + team_slug

   
    SELECT
    (
        SELECT team, [wins], [losses], [ties], [winning_percentage],
               (CASE
                   WHEN [games_back] = '0' THEN '-'
                   ELSE [games_back]
               END) AS [games_back],
               [overtime_losses], [standings_points]                                
          FROM @standings
         ORDER BY CAST([games_back] AS FLOAT) ASC, CAST(winning_percentage AS FLOAT) DESC, CAST([standings_points] AS INT) DESC
           FOR XML RAW('team'), TYPE
    ),
	(
        SELECT display, [column]
          FROM @columns
           FOR XML RAW('column'), TYPE
    )
    FOR XML PATH(''), ROOT('root')

    SET NOCOUNT OFF
END 

GO
