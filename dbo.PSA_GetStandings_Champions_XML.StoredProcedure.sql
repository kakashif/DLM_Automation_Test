USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetStandings_Champions_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetStandings_Champions_XML]
AS
-- =============================================
-- Author:		ikenticus
-- Create date:	09/15/2014
-- Description:	get Champions League standings
-- Update:		09/22/2014 - ikenticus: using ncaa-whitebg for euro leagues
--				09/25/2014 - ikenticus: fixing games-played
--              10/14/2014 - John Lin - remove league key from SMG_Standings
--              11/11/2014 - ikenticus - using rank to obtain position
--				05/14/2015 - ikenticus - obtain league_key from SMG_fnGetLeagueKey
--				05/21/2015 - ikenticus - swap ties with losses in calculating rank
--              08/26/2015 - ikenticus - SDI migration
--              09/17/2015 - ikenticus - adjusting for SDI null standings records
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('champions')
    DECLARE @season_key INT
    
    SELECT @season_key = season_key
      FROM dbo.SMG_Default_Dates
     WHERE league_key = 'champions' AND page = 'standings'

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
    VALUES ('name', 'TEAM'), ('games_played', 'GP'), ('record', 'W-T-L'), ('points', 'PTS')

	-- LEFT OUTER JOIN to get all teams for the season, even if no standings (SDI)
    INSERT INTO @stats (team_key, [column], value)
    SELECT st.team_key, ss.[column], ss.value
      FROM dbo.SMG_Teams AS st
      LEFT OUTER JOIN SportsEditDB.dbo.SMG_Standings AS ss
		ON ss.league_key = st.league_key AND ss.season_key = st.season_key AND ss.team_key = st.team_key
     WHERE st.league_key = @league_key AND st.season_key = @season_key

    DECLARE @standings TABLE
    (
        division_key VARCHAR(100),
        division_name VARCHAR(100),
        team_key VARCHAR(100),
        team_abbr VARCHAR(100),
        -- render
        name VARCHAR(100),
        games_played INT,
        wins INT,
        losses INT,
        ties INT,
        points INT,
		record VARCHAR(100),
        logo VARCHAR(100),
		position INT
    )

    INSERT INTO @standings (team_key, games_played, wins, losses, ties, points, position)
    SELECT p.team_key, [games-played], ISNULL([wins], 0), ISNULL([losses], 0), ISNULL([ties], 0), [points],
		   RANK() OVER(ORDER BY CAST(points AS INT) DESC, CAST(wins AS INT) DESC, CAST(ties AS INT) DESC, CAST(losses AS INT) ASC)
      FROM (SELECT team_key, [column], value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.[column] IN ([position], [games-played], [wins], [losses], [ties], [points])) AS p

    UPDATE s
       SET s.division_key =  sl.division_key,
           s.division_name =  sl.division_name,
           s.team_abbr = st.team_abbreviation,	
           s.name = st.team_display
      FROM @standings s
     INNER JOIN dbo.SMG_Teams st ON st.team_key = s.team_key AND st.league_key = @league_key AND st.season_key = @season_key
     INNER JOIN dbo.SMG_Leagues sl ON sl.league_key = st.league_key AND sl.season_key = st.season_key AND sl.division_key = st.division_key

	UPDATE @standings
	   SET games_played = wins + ties + losses
	 WHERE games_played IS NULL

	UPDATE @standings
	   SET points = wins * 3 + ties
	 WHERE points IS NULL

	UPDATE @standings
	   SET record = CAST(wins AS VARCHAR) + '-' + CAST(ties AS VARCHAR) + '-' + CAST(losses AS VARCHAR)

	UPDATE s
	   SET position = r.rank
	  FROM @standings AS s
	 INNER JOIN (
			SELECT RANK() OVER (ORDER BY points DESC, wins DESC, ties DESC, losses ASC) AS rank, team_key
			  FROM @standings
			) AS r ON r.team_key = s.team_key
	 WHERE s.position IS NULL

    -- render
    UPDATE @standings
       SET logo = dbo.SMG_fnTeamLogo('euro', team_abbr, '110')

    
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
            SELECT s.name, s.games_played, s.record, s.points, s.logo
              FROM @standings s
             WHERE s.division_key = conf_s.division_key
             ORDER BY position ASC
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
