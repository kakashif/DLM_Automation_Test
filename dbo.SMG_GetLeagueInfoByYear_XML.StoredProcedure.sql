USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetLeagueInfoByYear_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[SMG_GetLeagueInfoByYear_XML]
    @leagueName VARCHAR(100),
    @seasonKey INT
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 08/01/2013
  -- Update:	  10/01/2013 - ikenticus: adding team_name (perhaps update SMG_Teams instead?)
  --			  10/03/2013 - ikenticus: adding TSN key (for external TSN team links)
  --			  10/03/2013 - ikenticus: add NCAA teams-by-conference without-division
  --			  10/03/2013 - ikenticus: fixed team_display in SMG_Teams and removed MLS conditional
  --              10/08/2013 - John Lin - need to deprecate USAT_Team_Names
  --              10/17/2013 - John Lin - fix bug for NCAA
  --              10/21/2013 - John Lin - add team slug
  --              10/24/2013 - John Lin - remove code for team picker
  --              11/22/2013 - John Lin - use league name
  --              06/04/2014 - John Lin - LEFT JOIN USAT_Team_Names
  --              08/01/2014 - John Lin - check first and last for All-Stars
  --              05/21/2015 - ikenticus - refactor to support non-xmlteam and euro soccer
  --              05/28/2015 - John Lin - swap out sprite
  --              06/02/2015 - ikenticus - set default RGB to black, hard-code soccer league_display for now
  --              06/09/2015 - ikenticus - extending default RGB to empty string in addition to null
  --              07/08/2015 - John Lin - STATS migration for MLS
  --              08/20/2015 - John Lin - division display should have display
  --              08/24/2015 - John Lin - tier for NCAA
  --              09/03/2015 - ikenticus - SDI fixes: logo and conference_order
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    
	DECLARE @leagues TABLE
	(
		division_key VARCHAR(100),
		division_name VARCHAR(100),
		division_order INT,
		conference_key VARCHAR(100),
		conference_name VARCHAR(100),
		conference_order INT
	)

	IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw'))
	BEGIN
	    INSERT INTO @leagues (conference_key, conference_order, conference_name, division_key, division_order, division_name)
    	SELECT conference_key, conference_order, conference_display, division_key, division_order, division_display
	      FROM dbo.SMG_Leagues
    	 WHERE league_key = @league_key AND season_key = @seasonKey AND tier = 1
	END
	ELSE
	BEGIN
	    INSERT INTO @leagues (conference_key, conference_order, conference_name, division_key, division_order, division_name)
    	SELECT conference_key, conference_order, conference_display, division_key, division_order, division_display
	      FROM dbo.SMG_Leagues
    	 WHERE league_key = @league_key AND season_key = @seasonKey
    END
    
    -- remove extra entries from feed
    IF (@leagueName IN ('mlb'))
    BEGIN
        DELETE @leagues
         WHERE conference_key IS NULL OR conference_key = ''

        DELETE @leagues
         WHERE division_key IS NULL OR division_key = ''
    END


	DECLARE @teams TABLE
	(
		team_first VARCHAR(100),
		team_last VARCHAR(100),
		team_logo VARCHAR(100),
		team_rgb VARCHAR(100),
		link_team VARCHAR(100),
		link_schedule VARCHAR(100),
		link_statistics VARCHAR(100),
		link_roster VARCHAR(100),
        -- extra
		team_key VARCHAR(100),
		conference_key VARCHAR(100),
		division_key VARCHAR(100),
		team_abbr VARCHAR(100),
		team_slug VARCHAR(100)
	)

	INSERT INTO @teams (team_key, team_first, team_last, team_abbr, team_slug, team_rgb, conference_key, division_key)
	SELECT team_key, team_first, team_last, team_abbreviation, team_slug, rgb, conference_key, division_key
	  FROM dbo.SMG_Teams 
	 WHERE league_key = @league_key AND season_key = @seasonKey AND 'All-Stars' NOT IN (team_first, team_last)
	 ORDER BY team_first ASC

	-- default color = black
	UPDATE @teams
	   SET team_rgb = '127, 127, 127'
	 WHERE team_rgb IS NULL

	UPDATE @teams
	   SET team_rgb = '127, 127, 127'
	 WHERE team_rgb = ''

    -- logo
    IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw'))
    BEGIN
    	UPDATE @teams
	       SET team_logo = dbo.SMG_fnTeamLogo(@leagueName, team_abbr, '30')
	END
	ELSE
	BEGIN
    	UPDATE @teams
	       SET team_logo = dbo.SMG_fnTeamLogo(@leagueName, team_abbr, '80')
	END

    -- link
    IF (@leagueName IN ('mlb', 'nba', 'ncaaf', 'nfl'))
    BEGIN
        UPDATE @teams
           SET link_team = '/sports/' + @leagueName + '/' + team_slug + '/'
    END

    IF (@leagueName IN ('mlb', 'nba', 'ncaab', 'nfl', 'nhl', 'wnba'))
    BEGIN
        UPDATE @teams
           SET link_schedule = '/sports/' + @leagueName + '/' + team_slug + '/schedule/'
    END
    
    IF (@leagueName IN ('champions', 'natl', 'wwc', 'epl', 'mls'))
    BEGIN
        UPDATE @teams
           SET link_schedule = '/sports/soccer/' + @leagueName + '/' + team_slug + '/schedule/'
    END

    IF (@leagueName IN ('mlb', 'nba', 'nfl', 'nhl'))
    BEGIN
        UPDATE @teams
           SET link_statistics = '/sports/' + @leagueName + '/' + team_slug + '/statistics/'
    END

    IF (@leagueName IN ('mlb', 'nba', 'nfl', 'nhl', 'wnba'))
    BEGIN
        UPDATE @teams
           SET link_roster = '/sports/' + @leagueName + '/' + team_slug + '/roster/'
    END

    IF (@leagueName IN ('champions', 'natl', 'wwc', 'epl', 'mls'))
    BEGIN
        UPDATE @teams
           SET link_roster = '/sports/soccer/' + @leagueName + '/' + team_slug + '/roster/'
    END

	DECLARE @league_display VARCHAR(100)

	SET @league_display = CASE
								WHEN @leagueName = 'champions' THEN 'Champions League'
								WHEN @leagueName = 'wwc' THEN 'Women''s World Cup'
								WHEN @leagueName = 'natl' THEN 'World Cup'
								WHEN @leagueName IN ('epl', 'mls') THEN UPPER(@leagueName)
						  END



    IF (@leagueName = 'epl')
    BEGIN
        SELECT @league_display AS league_display,
        (
            SELECT
            (
                SELECT
                (
                    SELECT t.team_key, t.team_first, t.team_last, t.team_logo, t.team_rgb, t.link_team, t.link_schedule, t.link_statistics, t.link_roster
                      FROM @teams AS t
                     ORDER BY team_last ASC, team_first ASC
                       FOR XML RAW('team'), TYPE
                )
                FOR XML RAW('division'), TYPE
            )
            FOR XML RAW('conference'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END
    ELSE IF (@leagueName IN ('champions', 'natl', 'wwc'))
    BEGIN
        SELECT @league_display AS league_display,
        (
            SELECT
			(
                SELECT d.division_key, d.division_name,			
                (
                    SELECT t.team_key, t.team_first, t.team_last, t.team_logo, t.team_rgb, t.link_team, t.link_schedule, t.link_statistics, t.link_roster
                      FROM @teams AS t
                     WHERE t.division_key = d.division_key
                     ORDER BY team_last ASC, team_first ASC
                       FOR XML RAW('team'), TYPE
                )
                FROM @leagues AS d
                GROUP BY d.division_key, d.division_name, d.division_order
                ORDER BY d.division_order ASC
                FOR XML RAW('division'), TYPE
            )
            FOR XML RAW('conference'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END
    ELSE IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw'))
    BEGIN
        SELECT
        (
            SELECT c.conference_key, c.conference_name,
			(
                SELECT d.division_key, d.division_name,			
                (
                    SELECT t.team_key, t.team_first, t.team_logo, t.team_rgb, t.link_team, t.link_schedule, t.link_statistics, t.link_roster
                      FROM @teams AS t
                     WHERE t.conference_key = c.conference_key AND ISNULL(t.division_key, '') = ISNULL(d.division_key, '')
                     ORDER BY team_first ASC, team_last ASC
                       FOR XML RAW('team'), TYPE
                )
                FROM @leagues AS d
                WHERE d.conference_key = c.conference_key
                GROUP BY d.division_key, d.division_name, d.division_order
                ORDER BY d.division_order ASC
                FOR XML RAW('division'), TYPE
            )
            FROM @leagues AS c
            GROUP BY c.conference_key, c.conference_name, c.conference_order
            ORDER BY c.conference_order
            FOR XML RAW('conference'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END
    ELSE IF (@leagueName IN ('mls', 'wnba'))
    BEGIN
        SELECT @league_display AS league_display,
        (
            SELECT c.conference_key, c.conference_name,
			(
                SELECT c.conference_name AS division_name,			
                (
                    SELECT t.team_key, t.team_first, t.team_last, t.team_logo, t.team_rgb, t.link_team, t.link_schedule, t.link_statistics, t.link_roster
                      FROM @teams AS t
                     WHERE t.conference_key = c.conference_key
                     ORDER BY team_last ASC, team_first ASC
                       FOR XML RAW('team'), TYPE
                )
                FOR XML RAW('division'), TYPE
            )
            FROM @leagues AS c
            GROUP BY c.conference_key, c.conference_name, c.conference_order
            ORDER BY c.conference_order ASC
            FOR XML RAW('conference'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END
    ELSE
    BEGIN
        SELECT @league_display AS league_display,
        (
            SELECT c.conference_key, c.conference_name,
			(
                SELECT d.division_key, d.division_name,			
                (
                    SELECT t.team_key, t.team_first, t.team_last, t.team_logo, t.team_rgb, t.link_team, t.link_schedule, t.link_statistics, t.link_roster
                      FROM @teams AS t
                     WHERE t.conference_key = c.conference_key AND t.division_key = d.division_key
                     ORDER BY team_last ASC, team_first ASC
                       FOR XML RAW('team'), TYPE
                )
                FROM @leagues AS d
                WHERE d.conference_key = c.conference_key
                GROUP BY d.division_key, d.division_name, d.division_order
                ORDER BY d.division_order ASC
                FOR XML RAW('division'), TYPE
            )
            FROM @leagues AS c
            GROUP BY c.conference_key, c.conference_name, c.conference_order
            ORDER BY c.conference_order ASC
            FOR XML RAW('conference'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END


    SET NOCOUNT OFF
END 

GO
