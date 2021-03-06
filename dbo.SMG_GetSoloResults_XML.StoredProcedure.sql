USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetSoloResults_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SMG_GetSoloResults_XML]
    @leagueName VARCHAR(100),
    @seasonKey INT,
	@leagueId VARCHAR(100),
	@eventId INT
AS
--=============================================
-- Author:		ikenticus
-- Create date: 10/21/2013
-- Description: get Results for Solo Sports
--              10/24/2013 - ikenticus: adding golf individual stroke play
--				10/26/2013 - ikenticus: adding golf team match play
--				02/05/2014 - ikenticus: adding golf position-event
--				02/21/2014 - ikenticus: adding match play, team vs player, removing hole column
--              02/27/2014 - cchiu    : adding pga full leaderbord link for patch play pages
--				02/28/2014 - ikenticus: swapping rank for position-event for golf, removing winnings, adding pagetype
--				03/14/2014 - ikenticus: swapping Top 5 unique ranks back to Top 5th ranks
--				06/11/2014 - ikenticus: diverting all tennis result to another sproc
--				06/12/2014 - ikenticus: converting key columns logic from NULL to empty string
--				01/08/2015 - ikenticus: adding method to display Team Stroke Play results
--				01/30/2015 - ikenticus: replacing professional-golf-association with standardized league_id pga-tour
--				02/25/2015 - ikenticus: adding stats_switch to cutover to STATS when data ingestion complete
--				03/23/2015 - ikenticus: swapping nascar with golf and making motor-sports the default
--				04/27/2015 - ikenticus: replacing stats_switch with source from SMG_Default_Dates/SMG_Mappings
--				06/12/2015 - ikenticus: using function for current source league_key
--				06/18/2015 - ikenticus: adjusting for STATS empty purse ribbon
--				06/22/2015 - ikenticus: adjusting for STATS stableford golf scoring
--				07/02/2015 - ikenticus: removing dollars and cents from NASCAR purse if present, merging Duels/500 purses
--				07/07/2015 - ikenticus: Round < 5 for stroke play, fixing 0 score to display E
--				07/17/2015 - ikenticus: optimizing by replacing table calls with temp table
--				07/19/2015 - ikenticus: replacing team-match with cup
--				07/23/2015 - ikenticus: removing zero rank from leaderboard to avoid incorrect ordering
--				08/07/2015 - ikenticus: removing empty racing columns, fix SDI golf (stroke/stableford)
--				08/11/2015 - ikenticus: refactor to use separate sprocs
--				09/10/2015 - ikenticus - re-absorbing sprocs after migrating them to functions
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	DECLARE @archive XML

	SELECT @archive = archive
	  FROM dbo.SMG_Solo_Archive
	 WHERE league_id = @leagueId AND season_key = @seasonKey AND event_id = @eventId
	   AND platform = 'SMG' AND page = 'results'

	IF (@archive IS NULL)
	BEGIN
		IF (@leagueName = 'golf')
		BEGIN
			SELECT dbo.SMG_fnGetSoloResults_Golf_XML(@seasonKey, @leagueId, @eventId)
		END
		ELSE IF (@leagueName = 'tennis')
		BEGIN
			SELECT dbo.SMG_fnGetSoloResults_Tennis_XML(@seasonKey, @leagueId, @eventId)
		END
		ELSE
		BEGIN
			SELECT dbo.SMG_fnGetSoloResults_Racing_XML(@seasonKey, @leagueId, @eventId)
		END
    END
	ELSE
	BEGIN
		SELECT @archive
	END


    SET NOCOUNT OFF;
END


GO
