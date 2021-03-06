USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetScoresByDateFilter_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PSA_GetScoresByDateFilter_XML]
   @leagueName VARCHAR(100),
   @year       INT,
   @month      INT,
   @day        INT,
   @filter     VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 06/10/2014
  -- Description: get scores for ncaab for jameson
  -- Update: 10/23/2014 - John Lin - add round
  --         12/08/2014 - John Lin - add leagueName
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @start_date DATETIME = CAST(CAST(@year AS VARCHAR) + '-' + CAST(@month AS VARCHAR) + '-' + CAST(@day AS VARCHAR) AS DATETIME)

    EXEC dbo.PSA_GetScores_XML @leagueName, NULL, NULL, NULL, @start_date, @filter, NULL

END

GO
