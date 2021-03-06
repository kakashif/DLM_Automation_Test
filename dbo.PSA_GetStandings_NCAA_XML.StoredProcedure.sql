USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetStandings_NCAA_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetStandings_NCAA_XML]
    @leagueName VARCHAR(100),
    @affiliation VARCHAR(100)
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 07/02/2014
  -- Description: get NCAA standings
  --              09/08/2014 - ikenticus - switching to NCAA whitebg logos
  --              10/14/2014 - John Lin - remove league key from SMG_Standings
  --                                    - change order
  --              10/23/2014 - John Lin - change order
  --              05/14/2015 - ikenticus - obtain league_key from SMG_fnGetLeagueKey
  --              08/18/2015 - John Lin - SDI migration
  --              10/06/2015 - John Lin - filter on affiliation, remove no conference
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @season_key INT

    SELECT @season_key = season_key
      FROM dbo.SMG_Default_Dates
     WHERE league_key = @leagueName AND page = 'standings'

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
    VALUES ('name', 'TEAM'), ('wins', 'W'), ('losses', 'L'), ('wins-percentage', 'PCT'), ('conference-record', 'CONF')
        
    INSERT INTO @stats (team_key, [column], value)
    SELECT ss.team_key, ss.[column], ss.value
      FROM SportsEditDB.dbo.SMG_Standings ss
     INNER JOIN dbo.SMG_Teams st
        ON st.league_key = @league_key AND ss.season_key = st.season_key AND ss.team_key = st.team_key
     WHERE ss.season_key = @season_key

    DECLARE @standings TABLE
    (
        conference_key VARCHAR(100),
        conference_display VARCHAR(100),
        conference_order INT,
        division_key VARCHAR(100),
        division_display VARCHAR(100),
        division_order INT,
        team_key VARCHAR(100),
        -- render
        name VARCHAR(100),
        wins INT,
        losses INT,
        [wins-percentage] VARCHAR(100),
        [conference-record] VARCHAR(100),
        result_effect VARCHAR(100),
        logo VARCHAR(100),
        -- extra
        [away-wins] INT,
        [away-losses] INT,
        [home-wins] INT,
        [home-losses] INT,
        [conference-wins] INT,
        [conference-losses] INT,
        [conference-wins-percentage] VARCHAR(100),
        team_abbreviation VARCHAR(100)
    )
            
    INSERT INTO @standings (team_key, [away-wins], [away-losses], [home-wins], [home-losses], [conference-wins], [conference-losses], result_effect)
    SELECT p.team_key, ISNULL([away-wins], 0), ISNULL([away-losses], 0), ISNULL([home-wins], 0), ISNULL([home-losses], 0),
           ISNULL([conference-wins], 0), ISNULL([conference-losses], 0), result_effect
      FROM (SELECT team_key, [column], value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.[column] IN ([away-wins], [away-losses], [home-wins], [home-losses], [conference-wins], [conference-losses], result_effect)) AS p

    UPDATE @standings
       SET wins = [away-wins] + [home-wins],
           losses = [away-losses] + [home-losses]

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
                                        END,
           [conference-record] = CAST([conference-wins] AS VARCHAR) + '-' + CAST([conference-losses] AS VARCHAR)
           
    UPDATE @standings
       SET [wins-percentage] = REPLACE([wins-percentage], '0.', '.'),
           [conference-wins-percentage] = REPLACE([conference-wins-percentage], '0.', '.')
               
    UPDATE s
       SET s.conference_key = st.conference_key, s.division_key = st.division_key,
           s.name = st.team_first, s.team_abbreviation = st.team_abbreviation
      FROM @standings s
     INNER JOIN dbo.SMG_Teams st
        ON st.league_key = @league_key AND st.season_key = @season_key AND st.team_key = s.team_key


    UPDATE s
       SET s.conference_order =  sl.conference_order, s.conference_display =  sl.conference_display, s.division_display =  sl.division_display
      FROM @standings s
     INNER JOIN dbo.SMG_Leagues sl
        On sl.league_key = @league_key AND sl.season_key = @season_key AND sl.conference_key = s.conference_key AND ISNULL(sl.division_key, '') = ISNULL(s.division_key, '')

    -- conference
    DELETE @standings
     WHERE conference_display IS NULL
    
    DELETE @standings
     WHERE SportsEditDB.dbo.SMG_fnSlugifyName(conference_display) <> @affiliation

    -- render
    UPDATE @standings
       SET logo = 'http://www.gannett-cdn.com/media/SMG/sports_logos/ncaa-whitebg/110/' + team_abbreviation + '.png'



    SELECT
    (
        SELECT cd_s.division_display AS ribbon,
        (
	        SELECT column_name, column_display
		      FROM @columns
		     ORDER BY id ASC
		       FOR XML PATH('columns'), TYPE
	    ),
        (
            SELECT s.name, s.wins, s.losses, s.[wins-percentage], s.logo, s.result_effect AS [key], s.[conference-record]                   
              FROM @standings s
             WHERE s.conference_key = cd_s.conference_key AND ISNULL(s.division_key, '') = ISNULL(cd_s.division_key, '')
             ORDER BY CAST(s.[conference-wins-percentage] AS FLOAT) DESC, s.wins DESC, s.losses ASC, s.[conference-wins] DESC, s.[conference-losses] ASC
               FOR XML RAW('rows'), TYPE
        )
        FROM @standings cd_s
       GROUP BY cd_s.conference_key, cd_s.division_key, cd_s.division_display, cd_s.conference_order, cd_s.division_order
       ORDER BY cd_s.conference_order ASC, cd_s.division_order ASC
         FOR XML RAW('standings'), TYPE
    )
    FOR XML PATH(''), ROOT('root')
    
    SET NOCOUNT OFF
END 

GO
