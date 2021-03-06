USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[MOB_GetPolls_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[MOB_GetPolls_XML]
    @leagueName     VARCHAR(100)
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 01/07/2014
  -- Description: get polls for mobile
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    EXEC dbo.MOB_GetPollsByType_XML @leagueName, 'smg-usat'
    
    SET NOCOUNT OFF
END 

GO
