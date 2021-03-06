USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetEventDetailSolo_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetEventDetailSolo_XML] 
    @leagueName VARCHAR(100),
	@leagueId VARCHAR(100),
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author:      ikenticus
-- Create date: 07/23/2014
-- Description: get event detail for solo
-- Update:		03/26/2015 - ikenticus - adding motor
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 

    IF (@leagueName NOT IN ('golf', 'motor', 'nascar', 'tennis'))
    BEGIN
        RETURN
    END

	DECLARE @archive XML

	SELECT @archive = archive
	  FROM dbo.SMG_Solo_Archive
	 WHERE league_id = @leagueId AND season_key = @seasonKey AND event_id = @eventId
	   AND platform = 'PSA' AND page = 'detail'

	IF (@archive IS NULL)
	BEGIN
		IF (@leagueName = 'golf')
		BEGIN
			SELECT dbo.PSA_fnGetEventDetailSolo_Golf_XML(@leagueId, @seasonKey, @eventId)
		END
		ELSE IF (@leagueName = 'tennis')
		BEGIN
			SELECT dbo.PSA_fnGetEventDetailSolo_Tennis_XML(@leagueId, @seasonKey, @eventId)
		END
		ELSE
		BEGIN
			SELECT dbo.PSA_fnGetEventDetailSolo_Racing_XML(@leagueId, @seasonKey, @eventId)
		END
	END
	ELSE
	BEGIN
		SELECT @archive
	END

        
    SET NOCOUNT OFF;
END

GO
