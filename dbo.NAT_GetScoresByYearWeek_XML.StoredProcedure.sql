USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[NAT_GetScoresByYearWeek_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create PROCEDURE [dbo].[NAT_GetScoresByYearWeek_XML]
   @host   VARCHAR(100),
   @year   INT,
   @week   VARCHAR(100)
AS
  --=============================================
  -- Author: John Lin
  -- Create date: 05/21/2015
  -- Description: get scores for WWC for mobile
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    EXEC dbo.NAT_GetScores_XML @host, 'wwc', @year, NULL, @week, NULL, NULL

END

GO
