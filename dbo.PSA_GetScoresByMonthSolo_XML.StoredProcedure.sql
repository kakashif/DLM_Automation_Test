USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetScoresByMonthSolo_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetScoresByMonthSolo_XML]
	@leagueName	VARCHAR(100),
	@leagueId	VARCHAR(100),
	@year		INT,
	@month		INT
AS
--=============================================
-- Author:		ikenticus
-- Create date:	07/14/2014
-- Description: get scores by month for solo
-- Update:		10/02/2014 - ikenticus - adding MMA
--				03/26/2015 - ikenticus - adding motor
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    IF (@leagueName NOT IN ('golf', 'mma', 'motor', 'nascar', 'tennis'))
    BEGIN
        RETURN
    END

	IF (@leagueName = 'golf')
	BEGIN
		EXEC dbo.PSA_GetScoresByMonthSolo_Golf_XML @leagueId, @year, @month
	END
	ELSE IF (@leagueName = 'mma')
	BEGIN
		EXEC dbo.PSA_GetScoresByMonthSolo_MMA_XML @year, @month
	END
	ELSE IF (@leagueName = 'motor')
	BEGIN
		EXEC dbo.PSA_GetScoresByMonthSolo_Motor_XML @leagueId, @year, @month
	END
	ELSE IF (@leagueName = 'nascar')
	BEGIN
		EXEC dbo.PSA_GetScoresByMonthSolo_NASCAR_XML @leagueId, @year, @month
	END
	ELSE IF (@leagueName = 'tennis')
	BEGIN
		EXEC dbo.PSA_GetScoresByMonthSolo_Tennis_XML @leagueId, @year, @month
	END
   
END

GO
