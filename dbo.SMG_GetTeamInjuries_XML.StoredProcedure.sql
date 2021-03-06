USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetTeamInjuries_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SMG_GetTeamInjuries_XML]
   @leagueName	VARCHAR(100),
   @teamSlug	VARCHAR(100),
   @position	VARCHAR(100)
AS
--=============================================
-- Author:		ikenticus
-- Create date:	01/01/2015
-- Description:	get team injuries
-- Update:		01/06/2015 - ikenticus - excluding deleted roster players
--              04/08/2015 - John Lin - new head shot logic
--              06/09/2015 - ikenticus - applying switchover league_key logic, fixing affiliation/position filtering
--				08/03/2015 - ikenticus - adding team_rgb
--				08/24/2015 - ikenticus - bumping details/comments from varchar(100) to varchar(max)
--				09/11/2015 - ikenticus - correcting injuries logic
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)   
	DECLARE @season_key INT
	DECLARE @team_key VARCHAR(100)
	DECLARE @team_abbr VARCHAR(100)

	SELECT @season_key = season_key
	  FROM dbo.SMG_Default_Dates
	 WHERE league_key = @leagueName AND page = 'schedules'

	IF (@season_key IS NULL)
	BEGIN
		SELECT TOP 1 @season_key = season_key
		  FROM dbo.SMG_Teams
		 WHERE league_key = @league_key
		 GROUP BY season_key
		 ORDER BY season_key DESC
	END

    SELECT TOP 1 @team_key = team_key, @team_abbr = team_abbreviation
      FROM dbo.SMG_Teams
     WHERE league_key = @league_key AND team_slug = @teamSlug
	 ORDER BY season_key DESC


	DECLARE @injuries TABLE (
		conference_name		VARCHAR(100),
		team_key			VARCHAR(100),
		player_key			VARCHAR(100),
		position_regular	VARCHAR(100),
		injury_date			DATE,
		injury_type			VARCHAR(100),
		injury_details		VARCHAR(MAX),
		injury_class		VARCHAR(100),
		injury_side			VARCHAR(100),
		comment				VARCHAR(MAX),
		-- display fields
		player_name			VARCHAR(100),
		team_rgb			VARCHAR(100),
		team_abbr			VARCHAR(100),
		team_name			VARCHAR(100),
		uniform_number		VARCHAR(100),
		headshot			VARCHAR(100)
	)

	INSERT INTO @injuries (injury_date, injury_type, injury_details, injury_class, injury_side, comment, player_key)
	SELECT injury_date, injury_type, injury_details, injury_class, injury_side, comment, player_key
	  FROM dbo.SMG_Injuries
	 WHERE feed_key = @league_key

	UPDATE i
	   SET position_regular = r.position_regular, uniform_number = r.uniform_number, headshot = r.head_shot + '120x120/' + r.[filename],
		   team_key = t.team_key, team_rgb = t.rgb, team_abbr = t.team_abbreviation, team_name = t.team_display
	  FROM @injuries AS i
	 INNER JOIN dbo.SMG_Rosters AS r ON r.phase_status <> 'delete' AND r.player_key = i.player_key AND r.season_key = @season_key
	 INNER JOIN dbo.SMG_Teams AS t ON t.team_key = r.team_key AND t.season_key = r.season_key AND t.league_key = @league_key

	DELETE @injuries
	 WHERE team_key <> @team_key

	-- remove invalid injuries
	DELETE FROM @injuries
	 WHERE injury_date = '1900-01-01'


	DECLARE @ribbon VARCHAR(100) = 'Current Team Injuries'

	IF (@position != 'all')
	BEGIN
		SET @ribbon = @ribbon + ' (' + UPPER(@position) + ')'

		IF (@leagueName IN ('nfl', 'ncaaf'))
		BEGIN
			IF (@position = 'offense')
			BEGIN
				DELETE FROM @injuries
				 WHERE UPPER(position_regular) NOT IN ('C', 'QB', 'RB', 'WR', 'FB', 'G', 'LO', 'TE', 'TO' ,'SS')
			END
			ELSE IF (@position = 'defense')
			BEGIN
				DELETE FROM @injuries
				 WHERE UPPER(position_regular) NOT IN ('CB', 'DE', 'LB', 'S', 'TD', 'DB')
			END
			ELSE IF (@position = 'special')
			BEGIN
				DELETE FROM @injuries
				 WHERE UPPER(position_regular) NOT IN ('P', 'PK')
			END
		END
		ELSE IF (@leagueName = 'mlb' AND @position = 'of')
		BEGIN
			DELETE FROM @injuries
			 WHERE UPPER(position_regular) NOT IN ('OF', 'LF', 'CF', 'RF')
		END
		ELSE IF (@leagueName = 'nba')
		BEGIN
			DELETE FROM @injuries
			 WHERE RIGHT(position_regular, 1) != @position
		END
		ELSE
		BEGIN
			DELETE FROM @injuries
			 WHERE LOWER(position_regular) != @position
		END
	END


	UPDATE @injuries
	   SET i.player_name = p.first_name + ' ' + p.last_name
	  FROM @injuries AS i
	 INNER JOIN dbo.SMG_Players AS p ON p.player_key = i.player_key

	-- titlecase
	IF EXISTS (SELECT 1 FROM @injuries WHERE injury_type <> '')
	BEGIN
		UPDATE @injuries
		   SET injury_type = UPPER(LEFT(injury_type, 1)) + RIGHT(injury_type, LEN(injury_type) - 1),
			   injury_details = UPPER(LEFT(injury_details, 1)) + RIGHT(injury_details, LEN(injury_details) - 1),
			   injury_class = UPPER(LEFT(injury_class, 1)) + RIGHT(injury_class, LEN(injury_class) - 1),
			   comment = UPPER(LEFT(comment, 1)) + RIGHT(comment, LEN(comment) - 1)
	END


	DECLARE @columns TABLE (
		display	VARCHAR(100),
		tooltip VARCHAR(100),
		sort	VARCHAR(100),
		type	VARCHAR(100),
		id		VARCHAR(100)
	)

	INSERT INTO @columns (display, tooltip, sort, type, id)
	VALUES ('DATE', 'Injury Date', 'desc,asc', 'date', 'injury_date'),
		   ('NAME', 'Player Name', 'asc,desc', 'string', 'player_name'),
		   ('POS', 'Position', 'asc,desc', 'string', 'position_regular'),
		   ('INJURY', 'Injury Side/Type', 'asc,desc', 'string', 'injury_type'),
		   ('DETAILS', 'Injury Details', 'asc,desc', 'string', 'injury_details'),
		   ('STATUS', 'Injury Status', 'asc,desc', 'string', 'injury_class'),
		   ('NOTES', 'Injury Notes', 'asc,desc', 'string', 'comment')

	IF NOT EXISTS(SELECT 1 FROM @injuries WHERE injury_type <> '')
	BEGIN
		DELETE @columns WHERE id = 'injury_type'
	END

	IF NOT EXISTS(SELECT 1 FROM @injuries WHERE injury_details <> '')
	BEGIN
		UPDATE @injuries
		   SET injury_details = injury_class
	END

	IF NOT EXISTS(SELECT 1 FROM @injuries WHERE comment <> '')
	BEGIN
		DELETE @columns WHERE id = 'comment'
	END

	SELECT
	(
		SELECT @ribbon AS ribbon, @team_abbr AS team_abbr,
		(
			SELECT display, tooltip, sort, type, id
			  FROM @columns
			   FOR XML RAW('column'), TYPE
		),
		(
			SELECT injury_date, injury_type, injury_details, injury_class, injury_side,
				   comment, player_key, team_rgb, team_key, position_regular, player_name,
				   team_abbr, team_name, uniform_number, headshot
			  FROM @injuries
			   FOR XML RAW('row'), TYPE
		)
		 FOR XML RAW('table'), TYPE
	)
	FOR XML PATH(''), ROOT('root')

    SET NOCOUNT OFF
END


GO
