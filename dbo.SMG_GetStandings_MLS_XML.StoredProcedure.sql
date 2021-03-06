USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetStandings_MLS_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SMG_GetStandings_MLS_XML]
    @seasonKey INT,
    @affiliation VARCHAR(100)
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 09/27/2013
  -- Description: get MLS standings
  -- Update: 10/14/2014 - John Lin - remove league key from SMG_Standings
  --         11/04/2014 - John Lin - change clinched z to chinched y
  --         05/27/2015 - John Lin - swap out sprite
  --         06/02/2015 - ikenticus - adding hard-coded league_display for now
  --         07/07/2015 - John Lin - STATS migration
  --         07/15/2015 - John Lin - default sort by standing points
  --         09/03/2015 - ikenticus - SDI calculate points and played if empty
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('mls')
    DECLARE @logo_prefix VARCHAR(100) = 'http://www.gannett-cdn.com/media/SMG/sports_logos/'
    DECLARE @logo_folder VARCHAR(100) = '-whitebg/30/'
    DECLARE @legend_folder VARCHAR(100) = 'legends/clinched-'
    DECLARE @logo_suffix VARCHAR(100) = '.png'

    DECLARE @legend TABLE
    (
        [source] VARCHAR(100),
        [desc] VARCHAR(100)
    )
    INSERT INTO @legend ([source], [desc])
    VALUES (@logo_prefix + @legend_folder + 'z' + @logo_suffix, 'Clinched Conference'),
           (@logo_prefix + @legend_folder + 'y' + @logo_suffix, 'Clinched Playoff Berth'),
           (@logo_prefix + @legend_folder + 's' + @logo_suffix, 'Clinched Supporters'' Shield')
              
    DECLARE @columns TABLE
    (
        display VARCHAR(100),
        tooltip VARCHAR(100),
        [sort]  VARCHAR(100),
        [type]  VARCHAR(100),
        [column] VARCHAR(100)
    )    
    INSERT INTO @columns (display, tooltip, [sort], [type], [column])
    VALUES ('TEAM', 'Team', '', '', 'team'), ('P', 'Played', 'desc,asc', 'formatted-num', 'events_played'),
           ('W', 'Wins', 'desc,asc', 'formatted-num', 'wins'), ('L', 'Losses', 'asc,desc', 'formatted-num', 'losses'),
           ('T', 'Ties', 'desc,asc', 'formatted-num', 'ties'), ('GF', 'Goals For', 'desc,asc', 'formatted-num', 'points_scored_for'),
           ('GA', 'Goals Against', 'desc,asc', 'formatted-num', 'points_scored_against'), ('DIFF', 'Goals Differential', 'desc,asc', 'formatted-num', 'points_differential'),
           ('PTS', 'Standings Points', 'desc,asc', 'formatted-num', 'standing_points'), ('STRK', 'Streak', 'desc,asc', 'title-numeric', 'streak')

    DECLARE @standings TABLE
    (
        conference_key VARCHAR(100),
        conference_display VARCHAR(100),
        conference_order INT,
        team_key VARCHAR(100),
        team_abbr VARCHAR(100),
        team_slug VARCHAR(100),
        result_effect VARCHAR(100),
        -- render
        legend VARCHAR(100),
        logo VARCHAR(100),
        team VARCHAR(100),
        events_played INT,
        wins INT,
        losses INT,
        ties INT,
        points_scored_for INT,
        points_scored_against INT,
        points_differential VARCHAR(100),
        standing_points INT, -- extra
        streak VARCHAR(100)
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

    INSERT INTO @standings (team_key, events_played, wins, losses, ties, points_scored_for, points_scored_against,
                            standing_points, streak, result_effect)
    SELECT p.team_key, [events-played], [wins], [losses], [ties], [points-scored-for], [points-scored-against],
           [points], [streak], [result-effect]
      FROM (SELECT team_key, [column], value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.[column] IN ([events-played], [wins], [losses], [ties], [points-scored-for], [points-scored-against],
                                            [points], [streak], [result-effect])) AS p

	UPDATE @standings
	   SET events_played = wins + ties + losses
	 WHERE events_played = 0

	UPDATE @standings
	   SET standing_points = wins * 3 + ties
	 WHERE standing_points IS NULL

    UPDATE @standings
       SET result_effect = ''
     WHERE result_effect IS NULL OR result_effect = 'x'
    
    UPDATE s
       SET s.conference_key = sl.conference_key,
           s.conference_order =  sl.conference_order,
           s.conference_display =  sl.conference_display,
           s.team = st.team_first + ' ' + st.team_last,
           s.team_abbr = st.team_abbreviation,
           s.team_slug = st.team_slug
      FROM @standings s
     INNER JOIN dbo.SMG_Teams st
        ON st.team_key = s.team_key AND st.league_key = @league_key AND st.season_key = @seasonKey
     INNER JOIN dbo.SMG_Leagues sl
        On sl.league_key = st.league_key AND sl.season_key = st.season_key AND sl.conference_key = st.conference_key


    -- render
    UPDATE @standings
       SET legend = (CASE
                        WHEN result_effect <> '' THEN @logo_prefix + @legend_folder + result_effect + @logo_suffix
                        ELSE ''
                    END),
           logo = @logo_prefix + 'mls' + @logo_folder + team_abbr + @logo_suffix,
           points_differential = (CASE
                                     WHEN points_scored_for > points_scored_against THEN '+' + CAST((points_scored_for - points_scored_against) AS VARCHAR(100))
                                     WHEN points_scored_against > points_scored_for THEN '-' + CAST((points_scored_against - points_scored_for) AS VARCHAR(100))
                                     ELSE '0'
                                 END),
           streak = REPLACE(REPLACE(streak, 'Won ', '+'), 'Lost ', '-')


    IF (@affiliation = 'conference')
    BEGIN
        SELECT 'MLS' AS league_display,
	    (
            SELECT conf_s.conference_display AS ribbon, 'standing_points' AS default_column,
            (
                SELECT s.legend, s.logo, s.team, s.events_played, s.wins, s.losses, s.ties, s.points_scored_for, s.points_scored_against,
                       s.points_differential, s.standing_points, s.streak
                  FROM @standings s
                 WHERE s.conference_key = conf_s.conference_key
                 ORDER BY s.standing_points DESC
                   FOR XML RAW('row'), TYPE
            )
            FROM @standings conf_s
           GROUP BY conf_s.conference_key, conf_s.conference_display, conf_s.conference_order
           ORDER BY conf_s.conference_order ASC
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
    END
    ELSE
    BEGIN
        SELECT 'MLS' AS league_display,
	    (
	        SELECT 'MLS' AS ribbon, 'standing_points' AS default_column,
	        (
                SELECT s.legend, s.logo, s.team, s.events_played, s.wins, s.losses, s.ties, s.points_scored_for, s.points_scored_against,
                       s.points_differential, s.standing_points, s.streak
                  FROM @standings s
                 ORDER BY s.standing_points DESC
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
    END
    
    SET NOCOUNT OFF
END

GO
