USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetScoresBySeasonKeyWeek_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetScoresBySeasonKeyWeek_XML]
	@leagueName VARCHAR(100),
	@seasonKey INT,
	@week VARCHAR(100)
AS
--=============================================
-- Author:		ikenticus
-- Create date:	09/23/2014
-- Description:	get scores for euro soccer for jameson
-- Update: 10/23/2014 - John Lin - add round
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    EXEC dbo.PSA_GetScores_XML @leagueName, @seasonKey, NULL, @week, NULL, NULL, NULL

END

GO
