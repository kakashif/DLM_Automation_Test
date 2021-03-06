USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetNCAAFinancesBySchool_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[HUB_GetNCAAFinancesBySchool_XML]
    @schoolId INT
AS
-- =============================================
-- Author:		John Lin
-- Create date: 02/27/2013
-- Description:	Get list years profile for school
-- Update: 05/01/2014 - John Lin - left join since school might not have coaches' salary
--         05/12/2014 - John Lin - use school expense for school conference
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    SELECT
	(
        SELECT fnse.year,
               '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, fnse.scholarships), 1), 2) AS scholarships,
               '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, fnse.coaching_staff), 1), 2) AS coaching_staff,
               '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, fnse.building_grounds), 1), 2) AS building_grounds,
               '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, fnse.other), 1), 2) AS other,
               '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, fnse.total_expenses), 1), 2) AS total_expenses               
          FROM SportsEditDB.dbo.Feeds_NCAA_School_Expenses fnse
         WHERE fnse.school_id = @schoolId
         ORDER BY fnse.year DESC
           FOR XML RAW('expenses'), TYPE
    ),
    (
        SELECT fnsr.year,
               '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, fnsr.ticket_sales), 1), 2) AS ticket_sales,
               '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, fnsr.student_fees), 1), 2) AS student_fees,
               '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, fnsr.school_funds), 1), 2) AS school_funds,
               '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, fnsr.contributions), 1), 2) AS contributions,
               '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, fnsr.rights_licensing), 1), 2) AS rights_licensing,
               '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, fnsr.other), 1), 2) AS other,
               '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, fnsr.total_revenues), 1), 2) AS total_revenues
          FROM SportsEditDB.dbo.Feeds_NCAA_School_Revenues fnsr
         WHERE fnsr.school_id = @schoolId
         ORDER BY fnsr.year DESC
           FOR XML RAW('revenues'), TYPE
    ),
    (
       SELECT TOP 1
              fns.name AS school_name,
              fnse.conference,
              fnsm.team_abbr
         FROM SportsEditDB.dbo.Feeds_NCAA_Schools fns
        INNER JOIN SportsEditDB.dbo.Feeds_NCAA_Schools_Mappings fnsm
           ON fnsm.id = fns.id
        INNER JOIN SportsEditDB.dbo.Feeds_NCAA_School_Expenses fnse
           ON fnse.school_id = fns.id
        WHERE fns.id = @schoolId
        ORDER BY fnse.year DESC
          FOR XML RAW('profile'), TYPE
    )
    FOR XML PATH(''), ROOT('edits')
    
    SET NOCOUNT OFF;
END


GO
