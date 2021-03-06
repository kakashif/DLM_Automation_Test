USE [SportsDB]
GO
/****** Object:  View [dbo].[ViewEventTeamLeaders_NBA_Defense]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[ViewEventTeamLeaders_NBA_Defense]
-- =============================================
-- Author:		John Titchener
-- Create date: 8/1/2012
-- Description:	Gets Defense Team Leader statistics for NBA
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
			bds.blocks_per_game,
			bds.steals_per_game, 
			bds.blocks_total,
			bds.steals_total
	FROM
	dbo.[events] AS e  WITH (NOLOCK) 
	INNER JOIN dbo.affiliations_events AS ae 
		ON ae.event_id = e.id
	INNER JOIN dbo.affiliations AS a WITH (NOLOCK) 
		ON a.id = ae.affiliation_id
		AND a.affiliation_key = 'l.nba.com'
		AND a.affiliation_type = 'league'
	INNER JOIN dbo.stats AS defense_stats WITH (NOLOCK) 
		ON  defense_stats.stat_coverage_id = e.id
		AND defense_stats.stat_repository_type = 'basketball_defensive_stats'
		AND defense_stats.stat_holder_type = 'persons'
		AND defense_stats.stat_coverage_type = 'events'
		AND defense_stats.context = 'event'
	INNER JOIN dbo.basketball_defensive_stats AS bds WITH (NOLOCK) 
		ON bds.id = defense_stats.stat_repository_id
		--AND  (bds.blocks_per_game IS NOT NULL OR bds.steals_per_game IS NOT NULL)
	INNER JOIN dbo.person_event_metadata AS pem  WITH (NOLOCK) 
		ON pem.event_id = e.id
	INNER JOIN dbo.teams WITH (NOLOCK) 
		ON pem.team_id = teams.id
	INNER JOIN dbo.persons  WITH (NOLOCK) 
		ON pem.person_id =  persons.id
		AND defense_stats.stat_holder_id = persons.id
	INNER JOIN dbo.display_names AS dn WITH (NOLOCK) 
		ON dn.entity_id = persons.id
		AND dn.entity_type = 'persons'
	WHERE e.publisher_id IN (SELECT MAX(id) FROM dbo.publishers  WITH (NOLOCK) WHERE publisher_key = 'sportsnetwork.com');

GO
