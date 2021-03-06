USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetStandings_NBA_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[SMG_GetStandings_NBA_XML]
    @leagueKey VARCHAR(100),
    @seasonKey INT,
    @affiliation VARCHAR(100)
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 09/27/2013
  -- Description: get NBA standings
  -- Update: 01/14/2014 - John Lin - add team slug
  --         10/14/2014 - John Lin - remove league key from SMG_Standings
  --         05/27/2015 - John Lin - swap out sprite
  --         07/22/2015 - John Lin - STATS migration
  --         09/24/2015 - ikenticus - WNBA: removing division legend and calculating clinch
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_name VARCHAR(100)
    DECLARE @logo_prefix VARCHAR(100) = 'http://www.gannett-cdn.com/media/SMG/sports_logos/'
    DECLARE @logo_folder VARCHAR(100) = '-whitebg/30/'
    DECLARE @legend_folder VARCHAR(100) = 'legends/clinched-'
    DECLARE @logo_suffix VARCHAR(100) = '.png'
    
    SELECT @league_name = value_to
	  FROM dbo.SMG_Mappings
	 WHERE value_type = 'league' AND value_from = @leagueKey

    DECLARE @legend TABLE
    (
        [source] VARCHAR(100),
        [desc] VARCHAR(100)
    )
    INSERT INTO @legend ([source], [desc])
    VALUES (@logo_prefix + @legend_folder + 'z' + @logo_suffix, 'Clinched Conference'),
           (@logo_prefix + @legend_folder + 'y' + @logo_suffix, 'Clinched Divison'),
           (@logo_prefix + @legend_folder + 'x' + @logo_suffix, 'Clinched Playoff Berth')

	IF (@league_name = 'wnba')
	BEGIN
		DELETE @legend
		 WHERE [desc] = 'Clinched Divison'
	END

    DECLARE @columns TABLE
    (
        display VARCHAR(100),
        tooltip VARCHAR(100),
        [sort]  VARCHAR(100),
        [type]  VARCHAR(100),
        [column] VARCHAR(100)
    )
    INSERT INTO @columns (display, tooltip, [sort], [type], [column])
    VALUES ('TEAM', 'Team', '', '', 'team'), ('W', 'Wins', 'desc,asc', 'formatted-num', 'wins'), ('L', 'Losses', 'asc,desc', 'formatted-num', 'losses'),
           ('PCT', 'Win-Loss Ratio', 'desc,asc', 'formatted-num', 'win_loss_ratio'), ('GB', 'Games Back', 'asc,desc', 'formatted-num', 'games_back'),
           ('HOME', 'Home Record', 'desc,asc', 'formatted-num', 'home_record'), ('ROAD', 'Away Record', 'desc,asc', 'formatted-num', 'away_record'),
           ('CONF', 'Conference Record', 'desc,asc', 'formatted-num', 'conference_record'),
           ('PF', 'Points Scored For', 'desc,asc', 'formatted-num', 'points_scored_for'),
           ('PA', 'Points Scored Against', 'desc,asc', 'formatted-num', 'points_scored_against'),
           ('DIFF', 'Points Differential', 'desc,asc', 'formatted-num', 'points_differential'), ('L-10', 'L10', 'desc,asc', 'formatted-num', 'l10'),
           ('STRK', 'Streak', 'desc,asc', 'title-numeric', 'streak')
    
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
        [home-wins] INT,
        [home-losses] INT,
        [away-wins] INT,
        [away-losses] INT,
        conference_wins INT,
        conference_losses INT,
        l10_wins VARCHAR(100),
        l10_losses VARCHAR(100),
        -- render
        legend VARCHAR(100),
        logo VARCHAR(100),
        team VARCHAR(100),
        link VARCHAR(100),
        wins INT,
        losses INT,
        win_loss_ratio VARCHAR(100),
        games_back VARCHAR(100),
        home_record VARCHAR(100),
        away_record VARCHAR(100),
        conference_record VARCHAR(100),
        points_scored_for VARCHAR(100),
        points_scored_against VARCHAR(100),
        points_scored_for_float FLOAT,
        points_scored_against_float FLOAT,
        points_differential VARCHAR(100),
        l10 VARCHAR(100),
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
        ON st.league_key = @leagueKey AND ss.season_key = st.season_key AND ss.team_key = st.team_key
     WHERE ss.season_key = @seasonKey
            
    INSERT INTO @standings (team_key, games_back, [home-wins], [home-losses], [away-wins], [away-losses],
                            conference_wins, conference_losses, points_scored_for, points_scored_against, l10_wins, l10_losses, streak, result_effect)
    SELECT p.team_key, [games-back], [home-wins], [home-losses], [away-wins], [away-losses],
           [conference-wins], [conference-losses], [points-scored-for], [points-scored-against],
           [last-ten-games-wins], [last-ten-games-losses], [streak], [result-effect]
      FROM (SELECT team_key, [column], value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.[column] IN ([wins], [losses], [winning-percentage], [games-back], [home-wins], [home-losses],
                                            [away-wins], [away-losses], [conference-wins], [conference-losses],
                                            [points-scored-for], [points-scored-against],
                                            [last-ten-games-wins], [last-ten-games-losses], [streak], [result-effect])) AS p

    UPDATE @standings
       SET wins = [away-wins] + [home-wins],
           losses = [away-losses] + [home-losses]
           
    UPDATE @standings
       SET win_loss_ratio = CASE
                                WHEN wins + losses = 0 THEN '.000'
                                WHEN wins + losses = wins THEN '1.00'
                                ELSE REPLACE(CAST((CAST(wins AS FLOAT)/ (wins + losses)) AS DECIMAL(4, 2)), '0.', '.')
                            END
                            
    UPDATE @standings
       SET result_effect = ''
     WHERE result_effect IS NULL
     
    UPDATE @standings
       SET points_scored_for_float = CAST(points_scored_for AS FLOAT),
           points_scored_against_float = CAST(points_scored_against AS FLOAT)


    IF (@league_name = 'wnba')
    BEGIN
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
            ON st.league_key = @leagueKey AND st.season_key = @seasonKey AND st.team_key = s.team_key
         INNER JOIN dbo.SMG_Leagues sl
            On sl.league_key = st.league_key AND sl.season_key = st.season_key AND sl.conference_key = st.conference_key

        UPDATE @standings
           SET logo = @logo_prefix + 'wnba' + @logo_folder + 
               CASE
                  WHEN team_abbr = 'CON' THEN 'CON_'
                  ELSE team_abbr
               END + @logo_suffix

		IF NOT EXISTS (SELECT 1
						 FROM dbo.SMG_Schedules WHERE league_key = @leagueKey AND season_key = @seasonKey
						  AND sub_season_type = 'season-regular' AND event_status = 'pre-event')
		BEGIN
			UPDATE s
			   SET result_effect = CASE
									WHEN r.[rank] = 1 THEN 'z'
									WHEN r.[rank] BETWEEN 2 AND 4 THEN 'x'
									END
			  FROM @standings AS s
			 INNER JOIN (
					SELECT team_key, RANK() OVER (PARTITION BY conference_key ORDER BY CAST(win_loss_ratio AS FLOAT) DESC) AS [rank]
					  FROM @standings
				) AS r ON r.team_key = s.team_key
		END
    END
    ELSE
    BEGIN
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
            ON st.team_key = s.team_key AND st.league_key = @leagueKey AND st.season_key = @seasonKey
         INNER JOIN dbo.SMG_Leagues sl
            On sl.league_key = st.league_key AND sl.season_key = st.season_key AND sl.conference_key = st.conference_key AND sl.division_key = st.division_key

        UPDATE @standings
           SET logo = @logo_prefix + 'nba' + @logo_folder + team_abbr + @logo_suffix,
               link = '/sports/nba/' + team_slug + '/'
    END

    -- render
    -- CON.png hack
    UPDATE @standings
       SET legend = (CASE
                        WHEN result_effect <> '' THEN @logo_prefix + @legend_folder + result_effect + @logo_suffix
                        ELSE ''
                    END),
           home_record = CAST([home-wins] AS VARCHAR(100)) + ' - ' + CAST([home-losses] AS VARCHAR(100)),
           away_record = CAST([away-wins] AS VARCHAR(100)) + ' - ' + CAST([away-losses] AS VARCHAR(100)),
           conference_record = CAST(conference_wins AS VARCHAR(100)) + ' - ' + CAST(conference_losses AS VARCHAR(100)),
           points_differential = (CASE
                                   WHEN points_scored_for_float > points_scored_against_float
                                       THEN '+' + CAST(points_scored_for_float - points_scored_against_float AS VARCHAR(100))
                                   WHEN points_scored_against_float > points_scored_for_float
                                       THEN '-' + CAST(points_scored_against_float - points_scored_for_float AS VARCHAR(100))
                                   ELSE '0'
                               END),
           games_back = REPLACE(REPLACE(REPLACE(games_back, '1/2', '.5'), '.0', ''), ' ', ''),
           l10 = l10_wins + '-' + l10_losses,                               
           streak = REPLACE(REPLACE(streak, 'Won ', '+'), 'Lost ', '-')

    DECLARE @leaders TABLE
    (
        [key] VARCHAR(100),
        team_key VARCHAR(100),
        wins INT,
        losses INT
    )
    DECLARE @leader_wins INT
    DECLARE @leader_losses INT

    IF (@affiliation = 'league')
    BEGIN
        SELECT TOP 1 @leader_wins = wins, @leader_losses = losses
          FROM @standings
         ORDER BY CAST(win_loss_ratio AS FLOAT) DESC

        UPDATE @standings
           SET games_back = CAST((CAST((@leader_wins - wins) - (@leader_losses - losses) AS FLOAT) / 2.0) AS DECIMAL(6, 1))

        SELECT
	    (
	        SELECT UPPER(@league_name) AS ribbon, 'games_back' AS default_column,
	        (
                SELECT s.legend, s.logo, s.team, s.link, s.wins, s.losses, s.win_loss_ratio,
                       (CASE
                           WHEN s.games_back = '0.0' THEN '-'
                           ELSE s.games_back
                       END) AS games_back,
                       s.home_record, s.away_record, s.conference_record, s.points_scored_for, s.points_scored_against,
                       s.points_differential, s.l10, s.streak
                  FROM @standings s
                 ORDER BY CAST(s.games_back AS FLOAT) ASC
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
    ELSE IF (@affiliation = 'division')
    BEGIN
        INSERT INTO @leaders ([key])
        SELECT division_key
          FROM @standings
         GROUP BY division_key
        
        UPDATE @leaders
           SET team_key = (SELECT TOP 1 team_key
                             FROM @standings
                            WHERE division_key = [key]
                            ORDER BY CAST(win_loss_ratio AS FLOAT) DESC)

        UPDATE l
           SET l.wins = s.wins, l.losses = s.losses
          FROM @leaders l
         INNER JOIN @standings s
            ON s.division_key = l.[key] AND s.team_key = l.team_key

        UPDATE s
           SET s.games_back = CAST((CAST((l.wins - s.wins) - (l.losses - s.losses) AS FLOAT) / 2.0) AS DECIMAL(6, 1))
          FROM @standings s
         INNER JOIN @leaders l
            ON l.[key] = s.division_key

        SELECT
	    (
            SELECT div_s.division_name AS ribbon, 'games_back' AS default_column,
            (
                SELECT s.legend, s.logo, s.team, s.link, s.wins, s.losses, s.win_loss_ratio,
                       (CASE
                           WHEN s.games_back = '0.0' THEN '-'
                           ELSE s.games_back
                       END) AS games_back,
                       s.home_record, s.away_record, s.conference_record, s.points_scored_for, s.points_scored_against,
                       s.points_differential, s.l10, s.streak
                  FROM @standings s
                 WHERE s.division_key = div_s.division_key
                 ORDER BY CAST(s.games_back AS FLOAT) ASC
                   FOR XML RAW('row'), TYPE
            )
            FROM @standings div_s
           GROUP BY div_s.conference_order, div_s.division_key, div_s.division_name, div_s.division_order
           ORDER BY div_s.conference_order, div_s.division_order
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
    ELSE -- 'conference'
    BEGIN
        INSERT INTO @leaders ([key])
        SELECT conference_key
          FROM @standings
         GROUP BY conference_key
        
        UPDATE @leaders
           SET team_key = (SELECT TOP 1 team_key
                             FROM @standings
                            WHERE conference_key = [key]
                            ORDER BY CAST(win_loss_ratio AS FLOAT) DESC)

        UPDATE l
           SET l.wins = s.wins, l.losses = s.losses
          FROM @leaders l
         INNER JOIN @standings s
            ON s.conference_key = l.[key] AND s.team_key = l.team_key

        UPDATE s
           SET s.games_back = CAST((CAST((l.wins - s.wins) - (l.losses - s.losses) AS FLOAT) / 2.0) AS DECIMAL(6, 1))
          FROM @standings s
         INNER JOIN @leaders l
            ON l.[key] = s.conference_key

        SELECT
	    (
            SELECT conf_s.conference_name AS ribbon, 'games_back' AS default_column,
            (
                SELECT s.legend, s.logo, s.team, s.link, s.wins, s.losses, s.win_loss_ratio,
                       (CASE
                           WHEN s.games_back = '0.0' THEN '-'
                           ELSE s.games_back
                       END) AS games_back,
                       s.home_record, s.away_record, s.conference_record, s.points_scored_for, s.points_scored_against,
                       s.points_differential, s.l10, s.streak
                  FROM @standings s
                 WHERE s.conference_key = conf_s.conference_key
                 ORDER BY CAST(s.games_back AS FLOAT) ASC
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

    SET NOCOUNT OFF
END 

GO
