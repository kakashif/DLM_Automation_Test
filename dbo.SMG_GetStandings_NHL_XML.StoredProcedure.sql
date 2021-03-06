USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetStandings_NHL_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SMG_GetStandings_NHL_XML]
    @seasonKey INT,
    @affiliation VARCHAR(100)
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 09/27/2013
  -- Description: get NHL standings
  -- Update: 01/14/2014 - John Lin - add team slug
  --         10/14/2014 - John Lin - remove league key from SMG_Standings
  --         04/13/2015 - ikenticus - SOC-212: clinched president's trophy overrides conference
  --         05/27/2015 - John Lin - swap out sprite
  --         10/08/2015 - John Lin - SDI migration
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('nhl')
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
           (@logo_prefix + @legend_folder + 'y' + @logo_suffix, 'Clinched Division'),
           (@logo_prefix + @legend_folder + 'x' + @logo_suffix, 'Clinched Playoff Berth'),
           (@logo_prefix + @legend_folder + 's' + @logo_suffix, 'Clinched Presidents/Trophy')

    DECLARE @columns TABLE
    (
        display VARCHAR(100),
        tooltip VARCHAR(100),
        [sort]  VARCHAR(100),
        [type]  VARCHAR(100),
        [column] VARCHAR(100)
    )    
    INSERT INTO @columns (display, tooltip, [sort], [type], [column])
    VALUES ('TEAM', 'Team', '', '', 'team'), ('GP', 'Games Played', 'desc,asc', 'formatted-num', 'games_played'),
           ('W', 'Wins', 'desc,asc', 'formatted-num', 'wins'), ('L', 'Losses', 'asc,desc', 'formatted-num', 'losses'),
           ('OTL', 'Overtime Losses', 'asc,desc', 'formatted-num', 'overtime_losses'),
           ('PTS', 'Standings Points', 'desc,asc', 'formatted-num', 'standing_points'), ('HOME', 'Home Record', 'desc,asc', 'formatted-num', 'home_record'),
           ('ROAD', 'Away Record', 'desc,asc', 'formatted-num', 'away_record'), ('GF', 'Goals For', 'desc,asc', 'formatted-num', 'goals_for'),
           ('GA', 'Goals Against', 'desc,asc', 'formatted-num', 'goals_against'),
           ('DIFF', 'Goals Differential', 'desc,asc', 'formatted-num', 'goals_differential'), ('STRK', 'Streak', 'desc,asc', 'title-numeric', 'streak')

    DECLARE @standings TABLE
    (
        conference_key VARCHAR(100),
        conference_name VARCHAR(100),
        conference_order INT,
        division_key VARCHAR(100),
        division_name VARCHAR(100),
        division_order INT,
        team_key VARCHAR(100),
        team_abbr VARCHAR(100),
        team_slug VARCHAR(100),
        result_effect VARCHAR(100),        
        home_wins INT,
        home_losses INT,
        home_overtime_losses INT,
        away_wins INT,
        away_losses INT,
        away_overtime_losses INT,
        -- render
        legend VARCHAR(100),
        logo VARCHAR(100),
        team VARCHAR(100),
        games_played INT, -- statistics
        wins INT,
        losses INT,
        overtime_losses INT, -- extra
        standing_points INT, -- extra
        home_record VARCHAR(100),
        away_record VARCHAR(100),
        goals_for INT, -- extra
        goals_against INT, -- extra
        goals_differential VARCHAR(100),
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
        ON st.league_key = ss.league_key AND ss.season_key = st.season_key AND ss.team_key = st.team_key
     WHERE ss.league_key = @league_key AND ss.season_key = @seasonKey AND
           ss.[column] IN ('wins', 'losses', 'overtime-losses', 'standing-points', 'home-wins', 'home-losses',
                           'home-overtime-losses', 'away-wins', 'away-losses', 'away-overtime-losses', 'points-scored-for',
                           'points-scored-against', 'streak', 'result-effect')

            
    INSERT INTO @standings (team_key, goals_for, goals_against, streak, result_effect,
                            wins, losses, overtime_losses, home_wins, home_losses, home_overtime_losses, away_wins, away_losses, away_overtime_losses)
    SELECT p.team_key, ISNULL([points-scored-for], 0), ISNULL([points-scored-against], 0), [streak], [result-effect],
           ISNULL([wins], 0), ISNULL([losses], 0), ISNULL([overtime-losses], 0), 
           ISNULL([home-wins], 0), ISNULL([home-losses], 0), ISNULL([home-overtime-losses], 0),
           ISNULL([away-wins], 0), ISNULL([away-losses], 0), ISNULL([away-overtime-losses], 0)            
      FROM (SELECT team_key, [column], value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.[column] IN ([events-played], [points-scored-for], [points-scored-against], [streak], [result-effect],     
                                            [wins], [losses], [overtime-losses], [home-wins], [home-losses], [home-overtime-losses],
                                            [away-wins], [away-losses], [away-overtime-losses])) AS p

    UPDATE @standings
       SET games_played = (wins + overtime_losses + losses),
           standing_points = ((wins * 2) + overtime_losses)

    UPDATE @standings
       SET result_effect = ''
     WHERE result_effect IS NULL

	-- President's Trophy trumps all other results
    UPDATE @standings
       SET result_effect = 's'
     WHERE result_effect LIKE '%*'

	-- TSN sends it as 'zp' instead of the anticipated 'z*'
    UPDATE @standings
       SET result_effect = 's'
     WHERE result_effect LIKE '%p'
    
    UPDATE s
       SET s.conference_key = sl.conference_key,
           s.conference_name =  sl.conference_name,
           s.conference_order =  sl.conference_order,
           s.division_key =  sl.division_key,
           s.division_name =  sl.division_name,
           s.division_order =  sl.division_order,
           s.team = st.team_first + ' ' + st.team_last,
           s.team_abbr = st.team_abbreviation,
           s.team_slug = st.team_slug
      FROM @standings s
     INNER JOIN dbo.SMG_Teams st
        ON st.team_key = s.team_key AND st.league_key = @league_key AND st.season_key = @seasonKey
     INNER JOIN dbo.SMG_Leagues sl
        On sl.league_key = st.league_key AND sl.season_key = st.season_key AND sl.conference_key = st.conference_key AND sl.division_key = st.division_key


    -- render
    UPDATE @standings
       SET legend = (CASE
                        WHEN result_effect <> '' THEN @logo_prefix + @legend_folder + result_effect + @logo_suffix
                        ELSE ''
                    END),
           logo = @logo_prefix + 'nhl' + @logo_folder + team_abbr + @logo_suffix,
           home_record = CAST(home_wins AS VARCHAR) + '-' + CAST(home_losses AS VARCHAR) + '-' + CAST(home_overtime_losses AS VARCHAR),
           away_record = CAST(away_wins AS VARCHAR) + '-' + CAST(away_losses AS VARCHAR) + '-' + CAST(away_overtime_losses AS VARCHAR),
           goals_differential = (CASE
                                   WHEN goals_for > goals_against THEN '+' + CAST((goals_for - goals_against) AS VARCHAR)
                                   WHEN goals_against > goals_for THEN '-' + CAST((goals_against - goals_for) AS VARCHAR)
                                   ELSE '0'
                               END),
           streak = REPLACE(REPLACE(streak, 'Won ', '+'), 'Lost ', '-')
      
    
    IF (@affiliation = 'conference')
    BEGIN
        SELECT
	    (
            SELECT conf_s.conference_name AS ribbon, 'standing_points' AS default_column,
            (
                SELECT s.legend, s.logo, s.team, s.games_played, s.wins, s.losses, s.overtime_losses, s.standing_points, s.home_record,
                       s.away_record, s.goals_for, s.goals_against, s.goals_differential, s.streak
                  FROM @standings s
                 WHERE s.conference_key = conf_s.conference_key
                 ORDER BY s.standing_points DESC, s.wins DESC, s.overtime_losses ASC, s.losses ASC              
                   FOR XML RAW('row'), TYPE
            )
            FROM @standings conf_s
           GROUP BY conf_s.conference_key, conf_s.conference_name, conf_s.conference_order
           ORDER BY conf_s.conference_order
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
    ELSE IF (@affiliation = 'division')
    BEGIN    	
        SELECT
	    (
            SELECT div_s.division_name AS ribbon, 'standing_points' AS default_column,
            (
                SELECT s.legend, s.logo, s.team, s.games_played, s.wins, s.losses, s.overtime_losses, s.standing_points, s.home_record,
                       s.away_record, s.goals_for, s.goals_against, s.goals_differential, s.streak
                  FROM @standings s
                 WHERE s.division_key = div_s.division_key
                 ORDER BY s.standing_points DESC, s.wins DESC, s.overtime_losses ASC, s.losses ASC              
                   FOR XML RAW('row'), TYPE
            )
            FROM @standings div_s
           GROUP BY div_s.division_key, div_s.division_name, div_s.division_order
           ORDER BY div_s.division_order
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
        SELECT
	    (
	        SELECT 'NHL' AS ribbon, 'standing_points' AS default_column,
	        (
                SELECT s.legend, s.logo, s.team, s.games_played, s.wins, s.losses, s.overtime_losses, s.standing_points, s.home_record,
                       s.away_record, s.goals_for, s.goals_against, s.goals_differential, s.streak
                  FROM @standings s
                 ORDER BY s.standing_points DESC, s.wins DESC, s.overtime_losses ASC, s.losses DESC              
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
