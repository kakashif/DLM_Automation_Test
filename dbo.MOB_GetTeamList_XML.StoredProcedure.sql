USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[MOB_GetTeamList_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[MOB_GetTeamList_XML]
   @leagueName VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 01/28/2015
  -- Description: get team list for mobile
  -- Update: 03/16/2015 - John Lin - group by division for MLS
  --         05/18/2015 - John Lin - add Women's World Cup
  --         06/23/2015 - John Lin - STATS migration
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    IF (@leagueName NOT IN ('mlb', 'nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba',
                            'mls', 'wwc'))
    BEGIN
        SELECT 'invalid league name' AS [message], '400' AS [status]
           FOR XML PATH(''), ROOT('root')

        RETURN
    END

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @logo_prefix VARCHAR(100) = 'http://www.gannett-cdn.com/media/SMG/sports_logos/'
    DECLARE @flag_folder VARCHAR(100) = 'countries/flags/60/'
    DECLARE @logo_folder VARCHAR(100) = '-whitebg/60/'
    DECLARE @logo_suffix VARCHAR(100) = '.png'
   	DECLARE @season_key INT
    
    SELECT @season_key = team_season_key
      FROM dbo.SMG_Default_Dates
     WHERE league_key = @leagueName AND page = 'schedules'
         
	DECLARE @teams TABLE
	(
        team_key   VARCHAR(100),
        team_short VARCHAR(100),
        team_long  VARCHAR(100),
        team_abbr  VARCHAR(100),
        team_logo  VARCHAR(100),
        team_page  VARCHAR(100),
        -- group by
        conference_key VARCHAR(100),
        division_key VARCHAR(100),
        conference_order INT,
        division_order INT,
        group_name VARCHAR(100)
	)
	IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw'))
	BEGIN
        INSERT INTO @teams (team_key, team_short, team_long, team_abbr, team_logo, team_page, conference_key, division_key, conference_order, division_order, group_name)
        SELECT st.team_key, st.team_first, st.team_first + ' ' + st.team_last, st.team_abbreviation,
               @logo_prefix + 'ncaa' + @logo_folder + st.team_abbreviation + @logo_suffix,
               'http://www.usatoday.com/sports/' + @leagueName + '/' + st.team_slug + '/',
               st.conference_key, st.division_key, sl.conference_order, sl.division_order, sl.division_display
          FROM dbo.SMG_Teams st
         INNER JOIN dbo.SMG_Leagues sl
            ON sl.league_key = st.league_key AND sl.season_key = st.season_key AND sl.conference_key = st.conference_key AND sl.division_key = st.division_key
         WHERE st.league_key = @league_key AND st.season_key = @season_key AND st.team_slug IS NOT NULL
    END
    ELSE IF (@leagueName IN ('mlb', 'mls', 'nfl'))
    BEGIN
        IF (@leagueName = 'mls')
        BEGIN
            INSERT INTO @teams (team_key, team_short, team_long, team_abbr, team_logo, team_page, division_key, division_order, group_name)
            SELECT st.team_key, st.team_last, st.team_first + ' ' + st.team_last, st.team_abbreviation,
                   @logo_prefix + @leagueName + @logo_folder + st.team_abbreviation + @logo_suffix,
                   'http://www.usatoday.com/sports/soccer/' + @leagueName + '/' + st.team_slug + '/', st.division_key, sl.division_order, sl.division_name
              FROM dbo.SMG_Teams st
             INNER JOIN dbo.SMG_Leagues sl
                ON sl.league_key = st.league_key AND sl.season_key = st.season_key AND sl.conference_key = st.conference_key AND sl.division_key = st.division_key
             WHERE st.league_key = @league_key AND st.season_key = @season_key AND st.team_slug IS NOT NULL
        END
        ELSE
        BEGIN
            INSERT INTO @teams (team_key, team_short, team_long, team_abbr, team_logo, team_page, division_key, division_order, group_name)
            SELECT st.team_key, st.team_last, st.team_first + ' ' + st.team_last, st.team_abbreviation,
                   @logo_prefix + @leagueName + @logo_folder + st.team_abbreviation + @logo_suffix,
                   'http://www.usatoday.com/sports/' + @leagueName + '/' + st.team_slug + '/', st.division_key, sl.division_order, sl.division_name
              FROM dbo.SMG_Teams st
             INNER JOIN dbo.SMG_Leagues sl
                ON sl.league_key = st.league_key AND sl.season_key = st.season_key AND sl.conference_key = st.conference_key AND sl.division_key = st.division_key
             WHERE st.league_key = @league_key AND st.season_key = @season_key AND st.team_slug IS NOT NULL
        END
    END
    ELSE IF (@leagueName = 'wwc')
    BEGIN
        INSERT INTO @teams (team_key, team_short, team_long, team_abbr, team_logo, team_page, division_key, group_name)
        SELECT st.team_key, st.team_first, st.team_first, st.team_abbreviation,
               @logo_prefix + @flag_folder + st.team_abbreviation + @logo_suffix,
               'http://www.usatoday.com/sports/soccer/' + @leagueName + '/' + st.team_slug + '/', st.division_key, sl.division_name
          FROM dbo.SMG_Teams st
         INNER JOIN dbo.SMG_Leagues sl
            ON sl.league_key = st.league_key AND sl.season_key = st.season_key AND sl.division_key = st.division_key
         WHERE st.league_key = @league_key AND st.season_key = @season_key AND st.team_slug IS NOT NULL
    END
    ELSE
    BEGIN
        INSERT INTO @teams (team_key, team_short, team_long, team_abbr, team_logo, team_page, conference_key, conference_order, group_name)
        SELECT st.team_key, st.team_last, st.team_first + ' ' + st.team_last, st.team_abbreviation,
               @logo_prefix + @leagueName + @logo_folder + st.team_abbreviation + @logo_suffix,
               'http://www.usatoday.com/sports/' + @leagueName + '/' + st.team_slug + '/', st.conference_key, sl.conference_order, sl.conference_name
          FROM dbo.SMG_Teams st
         INNER JOIN dbo.SMG_Leagues sl
            ON sl.league_key = st.league_key AND sl.season_key = st.season_key AND sl.conference_key = st.conference_key AND sl.division_key = st.division_key
         WHERE st.league_key = @league_key AND st.season_key = @season_key AND st.team_slug IS NOT NULL
    END



    IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw'))
    BEGIN
        -- group by conference and division
        SELECT
	    (
            SELECT g.group_name,
            (
                SELECT team_key, team_short, team_long, team_abbr, team_logo, team_page
	             FROM @teams t
                 WHERE t.conference_key = g.conference_key AND t.division_key = g.division_key
 	            ORDER BY team_long ASC
                   FOR XML RAW('teams'), TYPE
            )
            FROM @teams g
           GROUP BY g.conference_key, g.division_key, g.group_name, g.conference_order, g.division_order
           ORDER BY g.conference_order ASC, g.division_order ASC
             FOR XML RAW('groups'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END
    ELSE IF (@leagueName IN ('mlb', 'mls', 'nfl'))
    BEGIN
        -- group by division
        SELECT
	    (
            SELECT g.group_name,
            (
                SELECT team_key, team_short, team_long, team_abbr, team_logo, team_page
	             FROM @teams t
                 WHERE t.division_key = g.division_key
 	            ORDER BY team_long ASC
                   FOR XML RAW('teams'), TYPE
            )
            FROM @teams g
           GROUP BY g.division_key, g.group_name, g.division_order
           ORDER BY g.division_order ASC
             FOR XML RAW('groups'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END
    ELSE IF (@leagueName = 'wwc')
    BEGIN
        -- group by division
        SELECT
	    (
            SELECT g.group_name,
            (
                SELECT team_key, team_short, team_long, team_abbr, team_logo, team_page
	             FROM @teams t
                 WHERE t.division_key = g.division_key
 	            ORDER BY team_long ASC
                   FOR XML RAW('teams'), TYPE
            )
            FROM @teams g
           GROUP BY g.division_key, g.group_name
           ORDER BY g.group_name ASC
             FOR XML RAW('groups'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END
    ELSE
    BEGIN
        -- group by conference
       SELECT
	    (
            SELECT g.group_name,
            (
                SELECT team_key, team_short, team_long, team_abbr, team_logo, team_page
	             FROM @teams t
                 WHERE t.conference_key = g.conference_key
 	            ORDER BY team_long ASC
                   FOR XML RAW('teams'), TYPE
            )
            FROM @teams g
           GROUP BY g.conference_key, g.group_name, g.conference_order
           ORDER BY g.conference_order ASC
             FOR XML RAW('groups'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END
END

GO
