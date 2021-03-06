USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetTeamInfoByYear_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SMG_GetTeamInfoByYear_XML]
    @leagueName VARCHAR(100),
    @teamSlug  VARCHAR(100),
    @seasonKey INT
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 08/01/2013
  -- Description: get team info of league
  -- Update: 01/17/2014 - John Lin - add more info
  --         02/19/2014 - ikenticus - adding legacy TSN key
  --         04/10/2014 - ikenticus - fixing category typo
  --         04/30/2014 - ikenticus - adding gallery parameters
  --         06/30/2014 - thlam - change the team_class to lower case
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	
	
    DECLARE @logo_prefix VARCHAR(100) = 'http://www.gannett-cdn.com/media/SMG/sports_logos/'
    DECLARE @logo_folder VARCHAR(100) = '-whitebg/110/'
    DECLARE @flag_folder VARCHAR(100) = 'countries/flags/110/'
    DECLARE @logo_suffix VARCHAR(100) = '.png'

	DECLARE @info TABLE
	(
	    league_key VARCHAR(100),
	    team_conference_key VARCHAR(100),
	    team_conference_display VARCHAR(100),
	    team_division_key VARCHAR(100),
	    team_division_display VARCHAR(100),
	    team_key VARCHAR(100),
		team_rgb VARCHAR(100),
		team_logo VARCHAR(100),
	    team_abbreviation VARCHAR(100),
	    team_full_name VARCHAR(100),
	    team_first_name VARCHAR(100),
	    team_last_name VARCHAR(100),
	    team_class VARCHAR(100),
	    team_category VARCHAR(100),
		team_tsn VARCHAR(100)
    )
    
    INSERT INTO @info (league_key)
	SELECT dbo.SMG_fnGetLeagueKey(@leagueName)

    IF (@leagueName IN ('ncaaf', 'ncaab', 'ncaaw'))
    BEGIN
        UPDATE i
           SET i.team_conference_key = st.conference_key, i.team_division_key = st.division_key, i.team_key = st.team_key,
               i.team_abbreviation = st.team_abbreviation, i.team_first_name = st.team_first, i.team_last_name = st.team_last,
			   i.team_rgb = st.rgb
          FROM @info i
         INNER JOIN dbo.SMG_Teams st
            ON st.league_key = i.league_key AND st.season_key = @seasonKey AND st.team_slug = @teamSlug
        
        UPDATE @info 
           SET team_class = team_abbreviation
    END
    ELSE
    BEGIN
        UPDATE i
           SET i.team_conference_key = st.conference_key, i.team_division_key = st.division_key, i.team_key = st.team_key,
               i.team_abbreviation = st.team_abbreviation, i.team_first_name = st.team_first, i.team_last_name = st.team_last,
			   i.team_rgb = st.rgb
          FROM @info i
         INNER JOIN dbo.SMG_Teams st
            ON st.league_key = i.league_key AND st.season_key = @seasonKey AND st.team_slug = @teamSlug
        
        UPDATE @info 
           SET team_class = @leagueName + LOWER(REPLACE(team_key, league_key + '-t.', ''))
    END

    UPDATE @info
       SET team_full_name = team_first_name + ' ' + team_last_name

	-- default color = black
	UPDATE @info
	   SET team_rgb = '0, 0, 0'
	 WHERE team_rgb IS NULL

    UPDATE i
       SET i.team_conference_display = sl.conference_display, i.team_division_display = sl.division_display
      FROM @info i
     INNER JOIN dbo.SMG_Leagues sl
        ON sl.league_key = i.league_key AND season_key = @seasonKey AND conference_key = i.team_conference_key ANd division_key = i.team_division_key

    IF (@leagueName = 'mlb')
    BEGIN
        UPDATE @info
           SET team_category = 'baseball'
    END
    ElSE IF (@leagueName IN ('mls', 'natl', 'wwc', 'epl', 'champions'))
    BEGIN
        UPDATE @info
           SET team_category = 'soccer'
    END
    ElSE IF (@leagueName IN ('nba', 'ncaab', 'ncaaw', 'wnba', 'wnba'))
    BEGIN
        UPDATE @info
           SET team_category = 'basketball'
    END
    ElSE IF (@leagueName IN ('nfl', 'ncaaf'))
    BEGIN
        UPDATE @info
           SET team_category = 'football'
    END
    ElSE IF (@leagueName = 'nhl')
    BEGIN
        UPDATE @info
           SET team_category = 'hockey'
    END

	-- Add TSN key
	UPDATE i
	   SET team_tsn = u.TSN FROM @info AS i	
	 INNER JOIN SportsDB.dbo.teams AS t ON t.team_key = i.team_key
     INNER JOIN SportsDB.dbo.USAT_Team_Names AS u ON u.entity_id = t.id

	-- GALLERY (SportsImages searchAPI)
	DECLARE @gallery_terms VARCHAR(100)
    IF (@leagueName IN ('ncaaf', 'ncaab', 'ncaaw'))
	BEGIN
		SELECT @gallery_terms = 'NCAA ' + team_category + ' ' + team_first_name FROM @info
	END
	ELSE
	BEGIN
		SELECT @gallery_terms = @leagueName + ' ' + team_full_name FROM @info
	END

    -- logo
    IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw'))
    BEGIN
        UPDATE @info
           SET team_logo = @logo_prefix + 'ncaa' + @logo_folder + team_abbreviation + @logo_suffix
    END
    ELSE IF (@leagueName IN ('epl', 'champions'))
    BEGIN
        UPDATE @info
           SET team_logo = @logo_prefix + 'euro' + @logo_folder + team_abbreviation + @logo_suffix
    END
    ELSE IF (@leagueName IN ('natl', 'wwc'))
    BEGIN
        UPDATE @info
           SET team_logo = @logo_prefix + @flag_folder + team_abbreviation + @logo_suffix
    END
    ELSE
    BEGIN
        UPDATE @info
           SET team_logo = @logo_prefix + @leagueName + @logo_folder +
               CASE
                   WHEN @leagueName = 'wnba' AND team_abbreviation = 'CON' THEN 'CON_'
                   ELSE team_abbreviation
               END + @logo_suffix
    END

	SELECT league_key, team_conference_key, team_conference_display, team_division_key, team_division_display, team_tsn,
           team_key, team_abbreviation, team_first_name, team_last_name, team_full_name, team_class, team_category,
           team_rgb, team_logo, @gallery_terms AS team_gallery_terms
      FROM @info
       FOR XML RAW('root'), TYPE


    SET NOCOUNT OFF
END 

GO
