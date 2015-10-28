USE [SportsDB]
GO
/****** Object:  View [dbo].[ViewEventTeamLeaders_NCAAF_Rushing]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[ViewEventTeamLeaders_NCAAF_Rushing]
-- =============================================
-- Author:		John Titchener
-- Create date: 8/1/2012
-- Description:	Gets Rushing Team Leader statistics for NCAAF
-- =============================================
AS
 	SELECT  teams.team_key,
			dn.first_name,
			dn.last_name,
			persons.person_key,
			persons.id AS person_id,
			e.event_key,
			e.id AS event_id,
			e.start_date_time,
			afrs.rushes_attempts,
			afrs.rushes_yards,
			afrs.rushes_touchdowns	
	FROM
	dbo.[events] AS e WITH (NOLOCK)
	INNER JOIN dbo.affiliations_events AS ae 
		ON ae.event_id = e.id
	INNER JOIN dbo.affiliations AS a  WITH (NOLOCK) 
		ON a.id = ae.affiliation_id
		AND a.affiliation_key = 'l.ncaa.org.mfoot'
		AND a.affiliation_type = 'league'
	INNER JOIN dbo.stats AS passing_stats  WITH (NOLOCK) 
		ON  passing_stats.stat_coverage_id = e.id
		AND passing_stats.stat_repository_type = 'american_football_rushing_stats'
		AND passing_stats.stat_holder_type = 'persons'
		AND passing_stats.stat_coverage_type = 'events'
		AND passing_stats.context = 'event'
	INNER JOIN dbo.american_football_rushing_stats  AS afrs  WITH (NOLOCK) 
		ON afrs.id = passing_stats.stat_repository_id
		AND  (afrs.rushes_attempts IS NOT NULL OR afrs.rushes_yards IS NOT NULL OR afrs.rushes_touchdowns IS NOT NULL)
	INNER JOIN dbo.person_event_metadata AS pem 
		ON pem.event_id = e.id
	INNER JOIN dbo.teams WITH (NOLOCK)
		on pem.team_id = teams.id
	INNER JOIN dbo.persons WITH (NOLOCK) 
		ON pem.person_id =  persons.id
		AND passing_stats.stat_holder_id = persons.id
	INNER JOIN dbo.display_names AS dn WITH (NOLOCK) 
		ON dn.entity_id = persons.id
		AND dn.entity_type = 'persons'
	WHERE e.publisher_id IN (SELECT MAX(id) FROM dbo.publishers  WITH (NOLOCK) WHERE publisher_key = 'sportsnetwork.com');


GO
