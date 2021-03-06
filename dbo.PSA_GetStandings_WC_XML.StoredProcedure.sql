USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetStandings_WC_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetStandings_WC_XML]
    @leagueName VARCHAR(100)
AS
-- =============================================
-- Author:		John Lin
-- Create date:	05/21/2015
-- Description:	get World Cup standings
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @season_key INT
    
    SELECT TOP 1 @season_key = season_key
      FROM SportsEditDB.dbo.SMG_Standings
     WHERE league_key = @leagueName
     ORDER BY season_key DESC

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
    VALUES ('name', 'TEAM'), ('record', 'W-T-L'), ('goals', 'GF-GA'), ('points', 'PTS')

    INSERT INTO @stats (team_key, [column], value)
    SELECT ss.team_key, ss.[column], ss.value
      FROM SportsEditDB.dbo.SMG_Standings ss
     INNER JOIN dbo.SMG_Teams st
        ON st.league_key = @league_key AND ss.season_key = st.season_key AND ss.team_key = st.team_key
     WHERE ss.season_key = @season_key AND ss.[column] IN ('wins', 'losses', 'ties', 'goals-for', 'goals-against', 'points')

    DECLARE @standings TABLE
    (
        division_key VARCHAR(100),
        division_name VARCHAR(100),
        team_key VARCHAR(100),
        team_abbr VARCHAR(100),
        -- render
        name VARCHAR(100),
        wins VARCHAR(100),
        losses VARCHAR(100),
        ties VARCHAR(100),
        goals_for VARCHAR(100),
        goals_against VARCHAR(100),
        points INT,
        logo VARCHAR(100)
    )

    INSERT INTO @standings (team_key, wins, losses, ties, goals_for, goals_against, points)
    SELECT p.team_key, [wins], [losses], [ties],[goals-for], [goals-against], [points]
      FROM (SELECT team_key, [column], value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.[column] IN ([wins], [losses], [ties],[goals-for], [goals-against], [points])) AS p

    UPDATE s
       SET s.division_key =  sl.division_key,
           s.division_name =  sl.division_name,
           s.team_abbr = st.team_abbreviation,	
           s.name = st.team_first
      FROM @standings s
     INNER JOIN dbo.SMG_Teams st
        ON st.league_key = @league_key AND st.team_key = s.team_key AND st.season_key = @season_key
     INNER JOIN dbo.SMG_Leagues sl
        ON sl.league_key = st.league_key AND sl.season_key = st.season_key AND sl.division_key = st.division_key

    -- render
    UPDATE @standings
       SET logo = 'http://www.gannett-cdn.com/media/SMG/sports_logos/countries/flags/110/' + UPPER(team_abbr) + '.png'

    
    SELECT
    (
        SELECT conf_s.division_name AS ribbon,
        (
	        SELECT column_name, column_display
		      FROM @columns
		     ORDER BY id ASC
		       FOR XML PATH('columns'), TYPE
	    ),
        (
            SELECT s.name, s.wins + '-' + s.ties + '-' + s.losses AS record, s.goals_for + '-' + s.goals_against AS goals, s.points, s.logo
              FROM @standings s
             WHERE s.division_key = conf_s.division_key
             ORDER BY points DESC
               FOR XML RAW('rows'), TYPE
        )
        FROM @standings conf_s
       GROUP BY conf_s.division_key, conf_s.division_name
       ORDER BY conf_s.division_name
         FOR XML RAW('standings'), TYPE
    )
    FOR XML PATH(''), ROOT('root')


    
    SET NOCOUNT OFF
END 

GO
