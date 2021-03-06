USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetEventBriefSoloMatch_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetEventBriefSoloMatch_XML] 
    @leagueName VARCHAR(100),
	@leagueId VARCHAR(100),
    @seasonKey INT,
    @eventId INT,
	@matchId INT
AS
-- =============================================
-- Author:      ikenticus
-- Create date: 09/08/2015
-- Description: get event brief for solo matches
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 

    IF (@leagueName NOT IN ('golf', 'motor', 'nascar', 'tennis'))
    BEGIN
        RETURN
    END

	IF (@leagueName = 'tennis')
	BEGIN
		EXEC dbo.PSA_GetEventBriefSoloMatch_Tennis_XML @leagueId, @seasonKey, @eventId, @matchId
	END
        
    SET NOCOUNT OFF;
END

GO
