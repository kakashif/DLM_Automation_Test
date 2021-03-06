USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[MOB_GetPollsByTypeYearWeek_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[MOB_GetPollsByTypeYearWeek_XML]
	@leagueName VARCHAR(100),
	@type       VARCHAR(100),
	@seasonKey  INT,
	@week       INT
AS
--=============================================
-- Author: John Lin
-- Create date: 01/08/2014
-- Description: get polls for mobile by type and week
-- Update:      02/26/2014 - John Lin - Coaches Poll rename to Amway Coaches Poll for ncaaf
--				03/20/2014 - ikenticus - using sponsor instead of hard-coded Amway, adding display_video flag
--				09/03/2014 - ikenticus - switching NCAA logos to whitebg per JIRA SMW-91
--			    07/01/2015 - ikenticus - adjusting to STATS migration and SMG_Polls* conversion
-- =============================================
BEGIN
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @published_on DATETIME
    DECLARE @type_display VARCHAR(100)
	DECLARE @video INT = 0

    SELECT TOP 1 @published_on = publish_date_time, @type_display = poll_name
	  FROM SportsEditDB.dbo.SMG_Polls
	 WHERE league_key = @leagueName AND season_key = @seasonKey AND fixture_key = @type AND [week] = @week AND
		   (publish_date_time IS NULL OR publish_date_time < GETDATE())

    IF (@type_display = 'AP')
    BEGIN
        SET @type_display = 'AP Poll'
    END
    ELSE IF (@type_display = 'BCS')
    BEGIN
        SET @type_display = 'BCS Poll'
    END
    ELSE IF (@type_display = 'Coaches Poll')
    BEGIN
		DECLARE @sponsor VARCHAR(100)

		SELECT @sponsor = [value]
		  FROM SportsEditDB.dbo.SMG_Data_Front_Attrs
		 WHERE LOWER(league_name) = LOWER(@leagueName)
		   AND page_id = 'smg-usat' AND name = 'sponsor'

		IF (@sponsor IS NOT NULL)
		BEGIN
			SET @type_display = @sponsor + ' Coaches Poll'
		END
		ELSE
		BEGIN
			SET @type_display = 'Coaches Poll'
		END

		DECLARE @max_week INT
		DECLARE @max_season INT
		SELECT TOP 1 @max_season = season_key, @max_week = [week]
		  FROM SportsEditDB.dbo.SMG_Polls
		 WHERE league_key = @leagueName AND fixture_key = @type
		 ORDER BY season_key DESC, [week] DESC

		IF (@seasonKey = @max_season AND @week = @max_week)
		BEGIN
			SELECT @video = [value]
			  FROM SportsEditDB.dbo.SMG_Data_Front_Attrs
			 WHERE LOWER(league_name) = LOWER(@leagueName)
			   AND page_id = 'smg-usat' AND name = 'polls_video'
		END
    END    
    ELSE IF (@type_display = 'Harris')
    BEGIN
        SET @type_display = 'Harris Poll'
    END
    

	DECLARE @polls TABLE (
        abbr               VARCHAR(100),
        first_name         VARCHAR(100),
        last_name          VARCHAR(100),
        full_name          VARCHAR(100),
        first_place_votes  INT,
        points             VARCHAR(100),
        ranking            VARCHAR(100),
        ranking_previous   VARCHAR(100),
        record             VARCHAR(100),
        logo               VARCHAR(100),
        ranking_diff	   INT,
        ranking_hilo       VARCHAR(100),
		ranking_mover	   VARCHAR(100),
		poll_date          DATE
	)

	INSERT INTO @polls (abbr, first_name, last_name, full_name, first_place_votes, points, ranking,
	                    ranking_previous, record, ranking_diff, ranking_hilo, ranking_mover, poll_date)
	SELECT st.team_abbreviation, st.team_first, st.team_last, st.team_first + ' ' + st.team_last, sp.first_place_votes, sp.points, sp.ranking,
	       ISNULL(sp.ranking_previous, 'NR'), CAST(sp.wins AS VARCHAR) + '-' + CAST(sp.losses AS VARCHAR),	       
           sp.ranking_diff, CAST(sp.ranking_hi AS VARCHAR) + '/' + CAST(sp.ranking_lo AS VARCHAR), sp.ranking_mover, sp.poll_date
	  FROM SportsEditDB.dbo.SMG_Polls AS sp
	 INNER JOIN dbo.SMG_Teams AS st
		ON st.season_key = sp.season_key AND st.team_abbreviation= sp.team_key
	 WHERE sp.league_key = @leagueName AND st.league_key = @league_key AND 
           sp.season_key = @seasonKey AND sp.fixture_key = @type AND sp.[week] = @week AND
		   (sp.publish_date_time IS NULL OR sp.publish_date_time < GETDATE())

    UPDATE @polls
       SET logo = 'http://www.gannett-cdn.com/media/SMG/sports_logos/ncaa-whitebg/22/' + abbr + '.png'      
    

	DECLARE @dropped_out VARCHAR(MAX)
	DECLARE @voters      VARCHAR(MAX)
	DECLARE @votes_other VARCHAR(MAX)
	DECLARE @notes       VARCHAR(MAX)
	
		
	SELECT @dropped_out = dropped_out, @voters = voters, @votes_other = votes_other, @notes = notes
	  FROM SportsEditDB.dbo.SMG_Polls_Info
	 WHERE league_key = @leagueName AND fixture_key = @type	AND poll_date = (SELECT TOP 1 poll_date FROM @polls)


	DECLARE @info TABLE (
		display VARCHAR(100),
		value   VARCHAR(MAX)
	)
	
	INSERT INTO @info (display, value)
	VALUES ('Schools Dropped Out', @dropped_out), ('List of Voters', @voters),
	       ('Others Receiving Votes', @votes_other), ('Misc Notes', @notes)

    UPDATE @info
       SET value = ''
     WHERE value IS NULL
     

    SELECT @published_on AS published_on, @type AS id, @type_display AS display, @week AS [week], @seasonKey AS [year], @video AS display_video,
    (
        SELECT abbr, first_name, last_name, full_name, first_place_votes, ranking, points, ranking_previous, record,
	           logo, ranking_diff, ranking_hilo
	      FROM @polls
		 ORDER BY CAST(ranking AS INT)
		   FOR XML RAW('poll'), TYPE
    ),
	(
		SELECT
		(
		    SELECT abbr, first_name, last_name, full_name, ranking, ranking_diff, logo
		      FROM @polls
			 WHERE ranking_mover = 'RISE'
			   FOR XML RAW('rise'), TYPE
		),
		(
			SELECT abbr, first_name, last_name, full_name, ranking, ranking_diff, logo
			  FROM @polls
		     WHERE ranking_mover = 'FALL'
			   FOR XML RAW('fall'), TYPE
		)
		FOR XML RAW('movers'), TYPE
	),
	(
	    SELECT display, value
	      FROM @info
		   FOR XML RAW('supplemental_data'), TYPE
	)
	FOR XML RAW('root'), TYPE

	
END


GO
