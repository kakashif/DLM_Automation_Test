USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetEventRoundSolo_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetEventRoundSolo_XML] 
    @leagueName VARCHAR(100),
	@leagueId VARCHAR(100),
    @seasonKey INT,
    @eventId INT,
	@round VARCHAR(100)
AS
-- =============================================
-- Author:      ikenticus
-- Create date: 07/26/2014
-- Description: get event round detail for solo
-- Update:		09/09/2015 - ikenticus - re-absorbing sprocs after migrating them to functions
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 

    IF (@leagueName NOT IN ('golf', 'tennis'))
    BEGIN
        RETURN
    END

	DECLARE @archive XML

	SELECT @archive = archive
	  FROM dbo.SMG_Solo_Archive
	 WHERE league_id = @leagueId AND season_key = @seasonKey AND event_id = @eventId
	   AND platform = 'PSA' AND page = @round


	IF (@leagueName = 'golf')
	BEGIN

		IF (@archive IS NULL)
		BEGIN
			SELECT dbo.PSA_fnGetEventRoundSolo_Golf_XML(@leagueId, @seasonKey, @eventId, @round)
		END
		ELSE
		BEGIN
			SELECT @archive
		END

	END
	ELSE IF (@leagueName = 'tennis')
	BEGIN

		IF (@archive IS NULL)
		BEGIN
			SET @archive = dbo.PSA_fnGetEventRoundSolo_Tennis_XML(@leagueId, @seasonKey, @eventId, @round)
		END

		SELECT
			(
				SELECT
					(
						SELECT node.query('match') FROM @archive.nodes('/') AS SMG(node)
					)
				   FOR XML RAW('round'), TYPE
			)
		   FOR XML PATH(''), ROOT('root')

	END
        
    SET NOCOUNT OFF;
END

GO
