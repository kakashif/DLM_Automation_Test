USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetEventBriefSolo_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetEventBriefSolo_XML] 
    @leagueName VARCHAR(100),
	@leagueId VARCHAR(100),
    @seasonKey INT,
    @eventId VARCHAR(100)
AS
-- =============================================
-- Author:      ikenticus
-- Create date: 07/16/2014
-- Description: get event brief for solo
-- Update:		03/26/2015 - ikenticus - adding motor
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 

    IF (@leagueName NOT IN ('golf', 'motor', 'nascar', 'tennis'))
    BEGIN
        RETURN
    END

	IF (@leagueName = 'golf')
	BEGIN
		EXEC dbo.PSA_GetEventBriefSolo_Golf_XML @leagueId, @seasonKey, @eventId
	END
	ELSE IF (@leagueName = 'motor')
	BEGIN
		EXEC dbo.PSA_GetEventBriefSolo_Motor_XML @leagueId, @seasonKey, @eventId
	END
	ELSE IF (@leagueName = 'nascar')
	BEGIN
		EXEC dbo.PSA_GetEventBriefSolo_NASCAR_XML @leagueId, @seasonKey, @eventId
	END
	ELSE IF (@leagueName = 'tennis')
	BEGIN
		EXEC dbo.PSA_GetEventBriefSolo_Tennis_XML @leagueId, @seasonKey, @eventId
	END
        
    SET NOCOUNT OFF;
END

GO
