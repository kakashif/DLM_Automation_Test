USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[MOB_GetScoresByDateFilter_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Stored Procedure

CREATE PROCEDURE [dbo].[MOB_GetScoresByDateFilter_XML]
   @year   INT,
   @month  INT,
   @day    INT,
   @filter VARCHAR(50)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 12/02/2013
  -- Description: get scores for ncaab for mobile
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @start_date DATETIME = CAST(CAST(@year AS VARCHAR) + '-' + CAST(@month AS VARCHAR) + '-' + CAST(@day AS VARCHAR) AS DATETIME)

    EXEC dbo.MOB_GetScores_XML 'ncaab', NULL, NULL, NULL, @start_date, @filter

END

GO
