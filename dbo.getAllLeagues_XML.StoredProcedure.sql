USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[getAllLeagues_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[getAllLeagues_XML] 
	@leagueKey VARCHAR(50)
AS
-- =============================================
-- Author:		Ramya Rangarajan
-- Create date: 5 May 2009
-- Description:	SProc to get the list of all leagues
-- 07/01/2012: ??? - Mods to add pseudo-league-keys
-- 50/15/2013: ikenticus - removed .com from league_name, used hyphens for spaces; added Golf, UFC, Motor Sports
-- 02/24/2014: ikenticus - add NCAABB league as an alternative to CWS
-- =============================================
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 

	DECLARE @publisherId int
	SET @publisherId = 2; --(SELECT id FROM dbo.publishers WHERE publisher_key = 'sportsnetwork.com')

	SELECT		1 AS tag,
				NULL AS parent,
				ISNULL(la.affiliation_key, '') AS [league!1!affiliation_key],
				ISNULL(dn.full_name, '') AS [league!1!full_name],
				ISNULL(ul.league_name, '') AS [league!1!league_name],
				ISNULL(ul.scores_page_sort, 0) AS [league!1!scores_page_sort],
				ISNULL(ul.scores_active, '') AS [league!1!scores_active],
				ISNULL(ul.league_scores_active, '') AS [league!1!league_scores_active],
				NULL AS [conference!2!conference_key],
				NULL AS [conference!2!conference_name],
				NULL AS [conference!2!conference_abbr_name]
				
	FROM		dbo.USAT_leagues AS ul
	INNER JOIN	dbo.affiliations AS la 
			ON	la.id = ul.league_id
	INNER JOIN	dbo.affiliations AS ca
			ON	ca.publisher_id = la.publisher_id
	INNER JOIN	dbo.display_names AS dn 
			ON	dn.entity_id = ca.id
			AND dn.entity_id = la.id
	WHERE		(ul.scores_active = 1 OR ul.league_scores_active = 1)
	AND		la.publisher_id = @publisherId
	AND		dn.entity_type = 'affiliations'
	AND		ca.affiliation_type = 'league'
	AND		(@leagueKey IS NULL OR la.affiliation_key = @leagueKey)
	
	UNION ALL
	
	SELECT		1 AS tag,
				NULL AS parent,
				'l.nascar.com' AS [league!1!affiliation_key],
				'NASCAR' AS [league!1!full_name],
				'nascar' AS [league!1!league_name],
				0 AS [league!1!scores_page_sort],
				1 AS [league!1!scores_active],
				1 AS [league!1!league_scores_active],
				NULL AS [conference!2!conference_key],
				NULL AS [conference!2!conference_name],
				NULL AS [conference!2!conference_abbr_name]
	
	UNION ALL
	
	SELECT		1 AS tag,
				NULL AS parent,
				'l.olympics.com' AS [league!1!affiliation_key],
				'Olympics' AS [league!1!full_name],
				'olympics' AS [league!1!league_name],
				0 AS [league!1!scores_page_sort],
				1 AS [league!1!scores_active],
				1 AS [league!1!league_scores_active],
				NULL AS [conference!2!conference_key],
				NULL AS [conference!2!conference_name],
				NULL AS [conference!2!conference_abbr_name]
	
	UNION ALL
	
	SELECT		1 AS tag,
				NULL AS parent,
				'l.fantasy.com' AS [league!1!affiliation_key],
				'Fantasy' AS [league!1!full_name],
				'fantasy' AS [league!1!league_name],
				0 AS [league!1!scores_page_sort],
				1 AS [league!1!scores_active],
				1 AS [league!1!league_scores_active],
				NULL AS [conference!2!conference_key],
				NULL AS [conference!2!conference_name],
				NULL AS [conference!2!conference_abbr_name]

	UNION ALL
	
	SELECT		1 AS tag,
				NULL AS parent,
				'l.mma.com' AS [league!1!affiliation_key],
				'MMA' AS [league!1!full_name],
				'mma' AS [league!1!league_name],
				0 AS [league!1!scores_page_sort],
				1 AS [league!1!scores_active],
				1 AS [league!1!league_scores_active],
				NULL AS [conference!2!conference_key],
				NULL AS [conference!2!conference_name],
				NULL AS [conference!2!conference_abbr_name]	

	UNION ALL
	
	SELECT		1 AS tag,
				NULL AS parent,
				'l.ufc.com' AS [league!1!affiliation_key],
				'UFC' AS [league!1!full_name],
				'ufc' AS [league!1!league_name],
				0 AS [league!1!scores_page_sort],
				1 AS [league!1!scores_active],
				1 AS [league!1!league_scores_active],
				NULL AS [conference!2!conference_key],
				NULL AS [conference!2!conference_name],
				NULL AS [conference!2!conference_abbr_name]

	UNION ALL
	
	SELECT		1 AS tag,
				NULL AS parent,
				'l.actionsports.com' AS [league!1!affiliation_key],
				'Action Sports' AS [league!1!full_name],
				'action-sports' AS [league!1!league_name],
				0 AS [league!1!scores_page_sort],
				1 AS [league!1!scores_active],
				1 AS [league!1!league_scores_active],
				NULL AS [conference!2!conference_key],
				NULL AS [conference!2!conference_name],
				NULL AS [conference!2!conference_abbr_name]
	
	UNION ALL

	SELECT		1 AS tag,
				NULL AS parent,
				'l.motorsports.com' AS [league!1!affiliation_key],
				'Motor Sports' AS [league!1!full_name],
				'motor-sports' AS [league!1!league_name],
				0 AS [league!1!scores_page_sort],
				1 AS [league!1!scores_active],
				1 AS [league!1!league_scores_active],
				NULL AS [conference!2!conference_key],
				NULL AS [conference!2!conference_name],
				NULL AS [conference!2!conference_abbr_name]
	
	UNION ALL
	
	SELECT		1 as tag,
				NULL as parent,
				'l.tennis.com' as [league!1!affiliation_key],
				'Tennis' as [league!1!full_name],
				'tennis' as [league!1!league_name],
				0 as [league!1!scores_page_sort],
				1 as [league!1!scores_active],
				1 as [league!1!league_scores_active],
				NULL as [conference!2!conference_key],
				NULL as [conference!2!conference_name],
				NULL as [conference!2!conference_abbr_name]
	
	UNION ALL
	
	SELECT		1 as tag,
				NULL as parent,
				'l.horseracing.com' AS [league!1!affiliation_key],
				'Horse Racing' AS [league!1!full_name],
				'horse-racing' AS [league!1!league_name],
				0 AS [league!1!scores_page_sort],
				1 AS [league!1!scores_active],
				1 AS [league!1!league_scores_active],
				NULL AS [conference!2!conference_key],
				NULL AS [conference!2!conference_name],
				NULL AS [conference!2!conference_abbr_name]
	
	UNION ALL
	
	SELECT		1 AS tag,
				NULL AS parent,
				'l.cycling.com' AS [league!1!affiliation_key],
				'Cycling' AS [league!1!full_name],
				'cycling' AS [league!1!league_name],
				0 AS [league!1!scores_page_sort],
				1 AS [league!1!scores_active],
				1 AS [league!1!league_scores_active],
				NULL AS [conference!2!conference_key],
				NULL AS [conference!2!conference_name],
				NULL AS [conference!2!conference_abbr_name]
	
	UNION ALL
	
	SELECT		1 AS tag,
				NULL AS parent,
				'l.highschool.com' AS [league!1!affiliation_key],
				'High School' AS [league!1!full_name],
				'high-school' AS [league!1!league_name],
				0 AS [league!1!scores_page_sort],
				1 AS [league!1!scores_active],
				1 AS [league!1!league_scores_active],
				NULL AS [conference!2!conference_key],
				NULL AS [conference!2!conference_name],
				NULL AS [conference!2!conference_abbr_name]
	
	UNION ALL
	
	SELECT		1 AS tag,
				NULL AS parent,
				'l.college.com' AS [league!1!affiliation_key],
				'College' AS [league!1!full_name],
				'college' AS [league!1!league_name],
				0 AS [league!1!scores_page_sort],
				1 AS [league!1!scores_active],
				1 AS [league!1!league_scores_active],
				NULL AS [conference!2!conference_key],
				NULL AS [conference!2!conference_name],
				NULL AS [conference!2!conference_abbr_name]
	
	UNION ALL
	
	SELECT		1 AS tag,
				NULL AS parent,
				'l.golf.com' AS [league!1!affiliation_key],
				'Golf' AS [league!1!full_name],
				'golf' AS [league!1!league_name],
				0 AS [league!1!scores_page_sort],
				1 AS [league!1!scores_active],
				1 AS [league!1!league_scores_active],
				NULL AS [conference!2!conference_key],
				NULL AS [conference!2!conference_name],
				NULL AS [conference!2!conference_abbr_name]
	
	UNION ALL
				
	SELECT		1 AS tag,
				NULL AS parent,
				'l.ncaa.org.mbase' AS [league!1!affiliation_key],
				'NCAABB' AS [league!1!full_name],
				'ncaabb' AS [league!1!league_name],
				0 AS [league!1!scores_page_sort],
				1 AS [league!1!scores_active],
				1 AS [league!1!league_scores_active],
				NULL AS [conference!2!conference_key],
				NULL AS [conference!2!conference_name],
				NULL AS [conference!2!conference_abbr_name]
	
	UNION ALL

	SELECT		2 AS tag,
				1 AS parent,
				la.affiliation_key AS [league!1!league_key],
				null,
				ISNULL(ul.league_name,'') AS [league!1!league_name],
				ISNULL(ul.scores_page_sort, 0) AS [league!1!scores_page_sort],
				NULL,
				NULL,
				ISNULL(ca.affiliation_key,''),
				ISNULL(dn.full_name,'x'),
				ISNULL(uc.conference_name,'y') 
				
	FROM		dbo.USAT_leagues AS ul 
	INNER JOIN	dbo.affiliations AS la 
			ON	la.id = ul.league_id
	INNER JOIN	dbo.affiliation_phases AS ap 
			ON	ap.ancestor_affiliation_id = la.id
	INNER JOIN	dbo.affiliations AS ca 
			ON	ca.id = ap.affiliation_id
			AND	ca.publisher_id = la.publisher_id
	INNER JOIN	dbo.display_names AS dn 
			ON	dn.entity_id = ca.id
	LEFT OUTER JOIN dbo.USAT_conferences AS uc 
			ON	uc.affiliation_id = ca.id	
					
	WHERE		(ul.scores_active = 1 OR ul.league_scores_active = 1)
	AND		dn.entity_type = 'affiliations'
	AND		ca.affiliation_type = 'conference'
	AND		ap.Root_id = ap.ancestor_affiliation_id
	AND		la.publisher_id = @publisherId
	AND		(@leagueKey IS NULL OR la.affiliation_key = @leagueKey)
	
	
	ORDER BY	[league!1!scores_page_sort],
				[conference!2!conference_key]
				
	FOR XML EXPLICIT, ROOT('leagues');

	SET NOCOUNT OFF;
END

GO
