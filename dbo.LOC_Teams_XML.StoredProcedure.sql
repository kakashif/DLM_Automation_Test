USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[LOC_Teams_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[LOC_Teams_XML]
   @leagueName VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 04/20/2015
  -- Description: get team list for USCP
  -- Update: 08/07/2015 - John Lin - SDI migration
  --         10/20/2015 - John Lin - replace USAT_Leagues with SMG_Mappings
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    IF (@leagueName NOT IN ('mlb', 'mls', 'nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba'))
    BEGIN
        RETURN
    END


    IF (@leagueName IN ('nfl', 'ncaaf'))
    BEGIN
        EXEC dbo.LOC_Teams_new_XML @leagueName
        RETURN
    END

    
    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
   	DECLARE @season_key INT
    DECLARE @sub_season_type VARCHAR(100)

    SELECT @season_key = team_season_key
      FROM dbo.SMG_Default_Dates
     WHERE league_key = @leagueName AND page = 'schedules'
         
	DECLARE @teams TABLE
	(
	    conference_key VARCHAR(100),
	    conference VARCHAR(100),
	    division_key VARCHAR(100),
	    division VARCHAR(100),
	    team_key VARCHAR(100),
        team_first VARCHAR(100),
        team_last VARCHAR(100),
        team_abbr VARCHAR(100),
        team_logo VARCHAR(100),
        team_slug VARCHAR(100),
        -- exhibition
        league_key VARCHAR(100),
        league_name VARCHAR(100)
	)
    INSERT INTO @teams (conference_key, division_key, team_key, team_first, team_last, team_abbr, team_slug)
    SELECT st.conference_key, st.division_key, st.team_key, st.team_first, st.team_last, st.team_abbreviation, st.team_slug
      FROM dbo.SMG_Teams st
     INNER JOIN dbo.SMG_Leagues sl
        ON sl.league_key = st.league_key AND sl.season_key = st.season_key AND sl.conference_key = st.conference_key AND sl.division_key = st.division_key
     WHERE st.league_key = @league_key AND st.season_key = @season_key AND st.team_slug IS NOT NULL

    -- All-Stars
    IF (@leagueName = 'mlb')
    BEGIN
        INSERT INTO @teams (conference, division, team_key, team_first, team_last, team_abbr, team_slug)
        SELECT 'American League', '', team_key, team_first, team_last, team_abbreviation, 'al'
          FROM dbo.SMG_Teams
         WHERE league_key = @league_key AND season_key = @season_key AND team_key = '321'

        INSERT INTO @teams (conference, division, team_key, team_first, team_last, team_abbr, team_slug)
        SELECT 'National League', '', team_key, team_first, team_last, team_abbreviation, 'nl'
          FROM dbo.SMG_Teams
         WHERE league_key = @league_key AND season_key = @season_key AND team_key = '322'
    END


    IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw'))
    BEGIN
        SET @sub_season_type = 'season-regular'

        UPDATE t
           SET t.conference = sl.conference_display, t.division = sl.division_display
          FROM @teams t
         INNER JOIN dbo.SMG_Leagues sl
            ON sl.league_key = @league_key AND sl.season_key = @season_key AND sl.conference_key = t.conference_key AND sl.division_key = t.division_key

        UPDATE @teams
           SET team_logo = 'http://www.gannett-cdn.com/media/SMG/sports_logos/ncaa-whitebg/60/' + team_abbr + '.png'
    END
    ELSE
    BEGIN
        SET @sub_season_type = 'pre-season'
        
        UPDATE t
           SET t.conference = sl.conference_display, t.division = sl.division_name
          FROM @teams t
         INNER JOIN dbo.SMG_Leagues sl
            ON sl.league_key = @league_key AND sl.season_key = @season_key AND sl.conference_key = t.conference_key AND sl.division_key = t.division_key

        UPDATE @teams
           SET team_logo = 'http://www.gannett-cdn.com/media/SMG/sports_logos/' + @leagueName + '-whitebg/60/' + team_abbr + '.png'
    END

    -- exhibition
    DECLARE @exhibition TABLE
    (
        team_key VARCHAR(100)
    )       
    INSERT INTO @exhibition (team_key)
    SELECT away_team_key
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @season_key AND sub_season_type = @sub_season_type

    INSERT INTO @exhibition (team_key)
    SELECT home_team_key
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @season_key AND sub_season_type = @sub_season_type

    DELETE e
      FROM @exhibition e
     INNER JOIN @teams t
        ON t.team_key = e.team_key    

    INSERT INTO @teams (conference, division, team_key)
    SELECT 'exhibition', 'exhibition', team_key
      FROM @exhibition
     GROUP BY team_key

    UPDATE t
       SET t.league_key = st.league_key, t.team_first = st.team_first, t.team_last = st.team_last, t.team_abbr = st.team_abbreviation, t.team_slug = st.team_slug
      FROM @teams t
     INNER JOIN dbo.SMG_Teams st
        ON st.season_key = @season_key AND st.team_key = t.team_key
     WHERE t.conference = 'exhibition' AND t.division = 'exhibition'

    UPDATE t
       SET t.league_name = sm.value_to
      FROM @teams t
	 INNER JOIN dbo.SMG_Mappings sm
        ON sm.value_type = 'league' AND sm.value_from = t.league_key
        
    UPDATE @teams
       SET team_logo = 'http://www.gannett-cdn.com/media/SMG/sports_logos/' +
                       CASE
                           WHEN league_name IN ('ncaab', 'ncaaf', 'ncaaw') THEN 'ncaa'
                           ELSE league_name
                       END +
                       '-whitebg/60/' + team_abbr + '.png'       
     WHERE conference = 'exhibition' AND division = 'exhibition'

    UPDATE @teams
       SET team_first = ''
     WHERE team_first IS NULL

    UPDATE @teams
       SET team_last = ''
     WHERE team_last IS NULL

    UPDATE @teams
       SET team_abbr = ''
     WHERE team_abbr IS NULL

    UPDATE @teams
       SET team_logo = ''
     WHERE team_logo IS NULL

    UPDATE @teams
       SET team_slug = ''
     WHERE team_slug IS NULL


    SELECT
    (
        SELECT conference, division, team_key, team_first, team_last, team_abbr, team_logo, team_slug
	      FROM @teams
           FOR XML PATH('teams'), TYPE
    )
    FOR XML PATH(''), ROOT('root')

END

GO
