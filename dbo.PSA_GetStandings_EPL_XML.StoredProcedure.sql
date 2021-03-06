USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetStandings_EPL_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetStandings_EPL_XML]
AS
-- =============================================
-- Author:		ikenticus
-- Create date:	09/15/2014
-- Description:	get EPL standings
-- Update:		09/22/2014 - ikenticus: using ncaa-whitebg for euro leagues
--				09/25/2014 - ikenticus: nesting output into standings node, fixing games-played
--              10/14/2014 - John Lin - remove league key from SMG_Standings
--				04/15/2015 - ikenticus: adding result_effect for EPL
--				05/14/2015 - ikenticus - obtain league_key from SMG_fnGetLeagueKey
--				08/12/2015 - ikenticus - sort the standings by points, wins, ties, losses
--              08/26/2015 - ikenticus - SDI migration
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('epl')
    DECLARE @season_key INT
    
    SELECT @season_key = season_key
      FROM dbo.SMG_Default_Dates
     WHERE league_key = 'epl' AND page = 'standings'

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
    VALUES ('position', 'POS'), ('name', 'TEAM'), ('games_played', 'GP'), ('record', 'W-T-L'), ('points', 'PTS')

    INSERT INTO @stats (team_key, [column], value)
    SELECT ss.team_key, ss.[column], ss.value
      FROM SportsEditDB.dbo.SMG_Standings ss
     INNER JOIN dbo.SMG_Teams st
        ON st.league_key = @league_key AND ss.season_key = st.season_key AND ss.team_key = st.team_key
     WHERE ss.season_key = @season_key

    DECLARE @standings TABLE
    (
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
		position INT,
		result_effect VARCHAR(100)
    )

    INSERT INTO @standings (team_key, position, games_played, wins, losses, ties, points)
    SELECT p.team_key, [position], [games-played], ISNULL([wins], 0), ISNULL([losses], 0), ISNULL([ties], 0), [points]
      FROM (SELECT team_key, [column], value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.[column] IN ([position], [games-played], [wins], [losses], [ties], [points])) AS p

    UPDATE s
       SET s.name = st.team_display, s.team_abbr = st.team_abbreviation
      FROM @standings s
     INNER JOIN dbo.SMG_Teams st
        ON st.team_key = s.team_key AND st.league_key = @league_key AND st.season_key = @season_key
     INNER JOIN dbo.SMG_Leagues sl
        On sl.league_key = st.league_key AND sl.season_key = st.season_key

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

    ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
    SELECT
    (
		SELECT 'true' AS 'json:Array',
		(
			SELECT column_name, column_display
			  FROM @columns
			 ORDER BY id ASC
			   FOR XML PATH('columns'), TYPE
		),
		(
			SELECT position, name, games_played, record, points, logo, result_effect as [key]
			  FROM @standings s
			 ORDER BY position ASC, points DESC, wins DESC, ties DESC, losses ASC
			   FOR XML RAW('rows'), TYPE
		)
         FOR XML RAW('standings'), TYPE
    )
    FOR XML PATH(''), ROOT('root')


    
    SET NOCOUNT OFF
END 

GO
