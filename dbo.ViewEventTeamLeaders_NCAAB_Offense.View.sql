USE [SportsDB]
GO
/****** Object:  View [dbo].[ViewEventTeamLeaders_NCAAB_Offense]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[ViewEventTeamLeaders_NCAAB_Offense]
-- =============================================
-- Author:		John Titchener
-- Create date: 8/1/2012
-- Description:	Gets Offense Team Leader statistics for NCAAB
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
			bos.points_scored_per_game,
			bos.field_goals_percentage,
			bos.free_throws_percentage
	FROM
	dbo.[events] AS e WITH (NOLOCK) 
	INNER JOIN dbo.affiliations_events AS ae WITH (NOLOCK) 
		ON ae.event_id = e.id
	INNER JOIN dbo.affiliations AS a WITH (NOLOCK) 
		ON a.id = ae.affiliation_id
		AND a.affiliation_key = 'l.ncaa.org.mbasket'
		AND a.affiliation_type = 'league'
	INNER JOIN dbo.stats AS off_stats  WITH (NOLOCK) 
		ON  off_stats.stat_coverage_id = e.id
		AND off_stats.stat_repository_type = 'basketball_offensive_stats'
		AND off_stats.stat_holder_type = 'persons'
		AND off_stats.stat_coverage_type = 'events'
		AND off_stats.context = 'event'
	INNER JOIN dbo.basketball_offensive_stats AS bos WITH (NOLOCK) 
		ON bos.id = off_stats.stat_repository_id
		AND  (bos.points_scored_per_game IS NOT NULL OR bos.field_goals_percentage IS NOT NULL OR bos.free_throws_percentage IS NOT NULL)
	INNER JOIN dbo.person_event_metadata AS pem WITH (NOLOCK) 
		ON pem.event_id = e.id
	INNER JOIN dbo.teams  WITH (NOLOCK) 
		ON pem.team_id = teams.id
	INNER JOIN dbo.persons  WITH (NOLOCK) 
		ON pem.person_id =  persons.id
		AND off_stats.stat_holder_id = persons.id
	INNER JOIN dbo.display_names AS dn WITH (NOLOCK) 
		ON dn.entity_id = persons.id
		AND dn.entity_type = 'persons'
	WHERE e.publisher_id IN (SELECT MAX(id) FROM dbo.publishers WITH (NOLOCK) WHERE publisher_key = 'sportsnetwork.com');

GO
