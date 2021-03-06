USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[MOB_GetStandings_WC_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[MOB_GetStandings_WC_XML]
    @leagueName VARCHAR(100),
    @seasonKey INT
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 05/20/2015
  -- Description: get world cup standings for mobile
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @standings TABLE
    (
        division_name VARCHAR(100),
        team_key VARCHAR(100),
        -- render
        team_abbreviation VARCHAR(100),
        long_name VARCHAR(100),
        [wins] INT,
        [losses] INT,
        [ties] INT,
        [goals-for] INT,
        [goals-against] INT,
        [points] VARCHAR(100),
        team_page VARCHAR(100),
        logo VARCHAR(100)
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
        ON st.league_key = @leagueName AND ss.season_key = st.season_key AND ss.team_key = st.team_key
     WHERE ss.season_key = @seasonKey AND ss.[column] IN ('wins', 'losses', 'ties', 'goals-for', 'goals-against', 'points')

    INSERT INTO @standings (team_key, [wins], [losses], [ties], [goals-for], [goals-against], [points])
    SELECT p.team_key, [wins], [losses], [ties], [goals-for], [goals-against], [points]
      FROM (SELECT team_key, [column], value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.[column] IN ([wins], [losses], [ties], [goals-for], [goals-against], [points])) AS p

    UPDATE s
       SET s.division_name =  sl.division_name,
           s.long_name = st.team_first,
           s.team_abbreviation = st.team_abbreviation,
           s.team_page = 'http://www.usatoday.com/sports/soccer/' + @leagueName + '/' + st.team_slug
      FROM @standings s
     INNER JOIN dbo.SMG_Teams st
        ON st.team_key = s.team_key AND st.league_key = @leagueName AND st.season_key = @seasonKey
     INNER JOIN dbo.SMG_Leagues sl
        On sl.league_key = st.league_key AND sl.season_key = st.season_key AND sl.division_key = st.division_key

    UPDATE @standings
       SET logo = 'http://www.gannett-cdn.com/media/SMG/sports_logos/countries/flags/22/' + team_abbreviation + '.png'

    
    SELECT
    (
        SELECT div_s.division_name AS ribbon,
        (
            SELECT s.team_abbreviation AS short_name, s.long_name, s.team_page, logo,
                   s.[wins], s.[losses], s.[ties], s.[goals-for], s.[goals-against], s.[points]
              FROM @standings s
             WHERE s.division_name = div_s.division_name
             ORDER BY s.[points] DESC, s.[wins] DESC, s.[ties] DESC, s.[losses] ASC
               FOR XML RAW('teams'), TYPE
        )
        FROM @standings div_s
       GROUP BY div_s.division_name
       ORDER BY div_s.division_name
         FOR XML RAW('standings'), TYPE
     )
     FOR XML PATH(''), ROOT('root')
    
    SET NOCOUNT OFF
END 

GO
