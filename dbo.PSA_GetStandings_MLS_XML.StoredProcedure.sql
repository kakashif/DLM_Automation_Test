USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetStandings_MLS_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PSA_GetStandings_MLS_XML]
AS
-- =============================================
-- Author:		John Lin
-- Create date:	07/02/2014
-- Description:	get MLS standings
-- Update:		10/09/2014 - John Lin - whitebg
--				10/14/2014 - John Lin - remove league key from SMG_Standings
--				02/18/2015 - ikenticus - MLS should display record as W-T-L
--				05/14/2015 - ikenticus - obtain league_key from SMG_fnGetLeagueKey
--              07/10/2015 - John Lin - STATS migration
--              08/26/2015 - ikenticus - SDI migration
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('mls')
    DECLARE @season_key INT
    
    SELECT @season_key = season_key
      FROM dbo.SMG_Default_Dates
     WHERE league_key = 'mls' AND page = 'standings'

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
    VALUES ('name', 'TEAM'), ('events_played', 'GP'), ('record', 'W-T-L'), ('standing_points', 'PTS')

    INSERT INTO @stats (team_key, [column], value)
    SELECT ss.team_key, ss.[column], ss.value
      FROM SportsEditDB.dbo.SMG_Standings ss
     INNER JOIN dbo.SMG_Teams st
        ON st.league_key = ss.league_key AND ss.season_key = st.season_key AND ss.team_key = st.team_key
     WHERE ss.league_key = @league_key AND ss.season_key = @season_key

    DECLARE @standings TABLE
    (
        conference_order INT,
        conference_key VARCHAR(100),
        conference_display VARCHAR(100),
        team_key VARCHAR(100),
        -- render
        name VARCHAR(100),
        events_played INT,
        wins INT,
        losses INT,
        ties INT,
        standing_points INT,
		record VARCHAR(100),
        result_effect VARCHAR(100),
        logo VARCHAR(100),
        -- extra
        team_abbreviation VARCHAR(100)
    )

    INSERT INTO @standings (team_key, events_played, wins, losses, ties, standing_points, result_effect)
    SELECT p.team_key, [events-played], ISNULL([wins], 0), ISNULL([losses], 0), ISNULL([ties], 0), [points], [result-effect]
      FROM (SELECT team_key, [column], value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.[column] IN ([events-played], [wins], [losses], [ties], [points], [result-effect])) AS p

	UPDATE @standings
	   SET events_played = wins + ties + losses
	 WHERE events_played = 0

	UPDATE @standings
	   SET standing_points = wins * 3 + ties
	 WHERE standing_points IS NULL

	UPDATE @standings
	   SET record = CAST(wins AS VARCHAR) + '-' + CAST(ties AS VARCHAR) + '-' + CAST(losses AS VARCHAR)

    UPDATE s
       SET s.conference_order = sl.conference_order,
           s.conference_key = sl.conference_key,
           s.conference_display =  sl.conference_display,
           s.name = st.team_display,
           s.team_abbreviation = st.team_abbreviation
      FROM @standings s
     INNER JOIN dbo.SMG_Teams st
        ON st.league_key = @league_key AND st.season_key = @season_key AND st.team_key = s.team_key
     INNER JOIN dbo.SMG_Leagues sl
        On sl.league_key = st.league_key AND sl.season_key = st.season_key AND sl.conference_key = st.conference_key

    -- render
    UPDATE @standings
       SET logo = 'http://www.gannett-cdn.com/media/SMG/sports_logos/mls-whitebg/110/' + team_abbreviation + '.png'

    -- switch result
    UPDATE @standings
       SET result_effect = ''
     WHERE result_effect = 'x'

    UPDATE @standings
       SET result_effect = 'x'
     WHERE result_effect = 'y'

    UPDATE @standings
       SET result_effect = 'y'
     WHERE result_effect = 'z'
    
    SELECT
    (
        SELECT conf_s.conference_display AS ribbon,
        (
	        SELECT column_name, column_display
		      FROM @columns
		     ORDER BY id ASC
		       FOR XML PATH('columns'), TYPE
	    ),
        (
            SELECT s.name, s.events_played, s.record, s.standing_points, s.logo, s.result_effect AS [key]
              FROM @standings s
             WHERE s.conference_key = conf_s.conference_key
             ORDER BY s.standing_points DESC, s.wins DESC, s.ties DESC, s.losses ASC
               FOR XML RAW('rows'), TYPE
        )
        FROM @standings conf_s
       GROUP BY conf_s.conference_key, conf_s.conference_display, conf_s.conference_order
       ORDER BY conf_s.conference_order
         FOR XML RAW('standings'), TYPE
    )
    FOR XML PATH(''), ROOT('root')


    
    SET NOCOUNT OFF
END 

GO
