USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[MOB_GetStandings_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[MOB_GetStandings_XML]
    @leagueName     VARCHAR(100)
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 01/07/2014
  -- Description: get standings for mobile
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @affiliation VARCHAR(100)
    
    SELECT @affiliation = filter
      FROM dbo.SMG_Default_Dates
     WHERE league_key = @leagueName AND page = 'standings'

    EXEC dbo.MOB_GetStandingsByAffiliation_XML @leagueName, @affiliation
    
    SET NOCOUNT OFF
END 

GO
