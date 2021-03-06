USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetNavUberSection_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[HUB_GetNavUberSection_XML]
    @xmlData XML = NULL
AS
-- =============================================
-- Author:		ikenticus
-- Create date: 09/17/2014
-- Description:	Get uber nav for non-sports taxonomy top_nav_primary sections
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;


	DECLARE @section VARCHAR(100)
	 SELECT @section = node.value('(Name/text())[1]', 'varchar(100)')
	   FROM @xmlData.nodes('//root') AS SMG(node)

	DECLARE @sections TABLE (
		section VARCHAR(100),
		name VARCHAR(100),
		slug VARCHAR(100),
		url VARCHAR(100),
		selected VARCHAR(100),
		[order] INT
	)

	INSERT INTO @sections ([order], section, name, slug, url, selected)
	SELECT menu_order, front_name, menu_name, pagetype, link_href, 'false'
	  FROM SportsEditDB.dbo.SMG_Sports_Nav_Menu
	 WHERE front_name IN ('main-section', 'social-links') AND pagetype != 'more'

	INSERT INTO @sections
		   (section, slug, name, url, [order])
	SELECT 'section',
		   node.value('(Name/text())[1]', 'varchar(100)'),
		   node.value('(Attributes/display/text())[1]', 'varchar(100)'),
		   node.value('(Attributes/url/text())[1]', 'varchar(100)'),
		   node.value('for $i in . return count(../*[. << $i]) + 1', 'int')
	  FROM @xmlData.nodes('//root/Children/item') AS SMG(node)

	UPDATE @sections
	   SET selected = 'true'
	 WHERE section = 'main-section' AND slug = @section

	UPDATE @sections
	   SET url = 'http://www.usatoday.com' + url
	 WHERE LEFT(url, 1) = '/'

	SELECT
		(
			SELECT name, slug, url, selected
			  FROM @sections
			 WHERE section = 'main-section'
			 ORDER BY [order]
			   FOR XML RAW('main-section'), TYPE
		),
		(
			SELECT name, slug, url
			  FROM @sections
			 WHERE section = 'section'
			 ORDER BY [order]
			   FOR XML RAW('section'), TYPE
		),
		(
			SELECT slug, url
			  FROM @sections
			 WHERE section = 'social-links'
			 ORDER BY [order]
			   FOR XML RAW('social-links'), TYPE
		)
	FOR XML PATH(''), ROOT('root')

    
    SET NOCOUNT OFF;
END

GO
