USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetTransactions_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[DES_GetTransactions_XML]
	@leagueName VARCHAR(100),
	@teamSlug VARCHAR(100)
AS
--=============================================
-- Author:		ikenticus
-- Create date:	06/03/2015
-- Description: get transactions by date for desktop
-- Update:		08/24/2015 - ikenticus: updating transactions column to varchar(max)
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    IF (@leagueName NOT IN ('mlb', 'nba', 'nfl', 'nhl', 'ncaaf', 'ncaab', 'wnba', 'mls'))
    BEGIN
        RETURN
    END
    
    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @logo_prefix VARCHAR(100) = 'http://www.gannett-cdn.com/media/SMG/sports_logos/'
    DECLARE @logo_folder VARCHAR(100) = '-whitebg/30/'
    DECLARE @flag_folder VARCHAR(100) = 'countries/flags/30/'
    DECLARE @logo_suffix VARCHAR(100) = '.png'
    DECLARE @team_key VARCHAR(100)
	DECLARE @ribbon VARCHAR(100)
	DECLARE @days INT = 7

	IF (@leagueName = 'nba')
	BEGIN
		SET @days = 30
	END

	DECLARE @columns TABLE (
		display VARCHAR(100),
		id VARCHAR(100)
	)

	INSERT INTO @columns (display, id)
	VALUES ('DATE', 'date'), ('TEAM', 'team_logo'), ('PLAYER', 'player_display'), ('TRANSACTION', 'transaction')

	DECLARE @transactions TABLE (
        player_key      VARCHAR(100),
        player_pos      VARCHAR(100),
        player_name     VARCHAR(100),
        player_display  VARCHAR(100),
        team_key        VARCHAR(100),
        team_abbr       VARCHAR(100),
        team_name       VARCHAR(100),
        team_logo       VARCHAR(100),
		[transaction]	VARCHAR(MAX),
		[date]			DATE
	)

	INSERT INTO @transactions (team_key, player_key, [transaction], [date])
	SELECT team_key, player_key, [transaction], [date]
	  FROM dbo.SMG_Transactions
	 WHERE league_key = @league_key AND date > DATEADD(DD, -@days, GETDATE())
	 ORDER BY date DESC

	IF (@teamSlug <> 'all')
	BEGIN
		SELECT TOP 1 @team_key = team_key, @ribbon = team_display
		  FROM dbo.SMG_Teams
		 WHERE league_key = @league_key AND team_slug = @teamSlug
		 ORDER BY season_key DESC
	END

	IF (@team_key IS NOT NULL)
	BEGIN
		DELETE @transactions
		 WHERE team_key <> @team_key

		DELETE @columns
		 WHERE display = 'TEAM'
	END
	ELSE
	BEGIN
		SET @ribbon = UPPER(@leagueName)
	END

	UPDATE x
	   SET team_abbr = t.team_abbreviation, team_name = t.team_display
	  FROM @transactions AS x
	 INNER JOIN dbo.SMG_Teams AS t ON t.team_key = x.team_key

	UPDATE x
	   SET player_name = p.first_name + ' ' + p.last_name
	  FROM @transactions AS x
	 INNER JOIN dbo.SMG_Players AS p ON p.player_key = x.player_key

	UPDATE x
	   SET player_pos = UPPER(r.position_regular)
	  FROM @transactions AS x
	 INNER JOIN dbo.SMG_Rosters AS r ON r.player_key = x.player_key AND r.team_key = x.team_key

	UPDATE @transactions
	   SET player_display = CASE
								WHEN player_pos IS NULL THEN player_name
								ELSE player_name + ', ' + player_pos
							END

    -- logo
    IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw'))
    BEGIN
        UPDATE @transactions
           SET team_logo = @logo_prefix + 'ncaa' + @logo_folder + team_abbr + @logo_suffix
    END
    ELSE
    BEGIN
        -- CON.png hack
        UPDATE @transactions
           SET team_logo = @logo_prefix + @leagueName + @logo_folder + 
                                CASE
                                    WHEN @leagueName = 'wnba' AND team_abbr = 'CON' THEN 'CON_'
                                    ELSE team_abbr
                                END + @logo_suffix
    END

	DELETE @transactions
	 WHERE player_display IS NULL

    SELECT @ribbon + ' Transactions For The Last ' + CAST(@days AS VARCHAR) + ' Days' AS ribbon,
	(
		SELECT display, id
		  FROM @columns
		   FOR XML RAW('columns'), TYPE
	),
	(
		SELECT player_display, team_logo, [transaction], [date] 
		  FROM @transactions
		 ORDER BY [date] DESC
		   FOR XML RAW('rows'), TYPE
    )
    FOR XML PATH(''), ROOT('root')

END

GO
