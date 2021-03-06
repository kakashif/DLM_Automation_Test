USE [SportsDB]
GO
/****** Object:  View [dbo].[ViewEventTeamLeaders_NHL_Offense]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[ViewEventTeamLeaders_NHL_Offense]
-- =============================================
-- Author:		John Titchener
-- Create date: 8/1/2012
-- Description:	Gets Offense Team Leader statistics for NHL
-- =============================================
AS
	SELECT
		teams.team_key,
		player_names.first_name,
		player_names.last_name,
		persons.person_key,
		persons.id AS person_id,
		e.event_key,
		e.id AS event_id,
		e.start_date_time,
		plays.goal_order,
		event_states.period_time_elapsed
	FROM 
	dbo.ice_hockey_action_participants AS players   WITH (NOLOCK) 
	INNER JOIN dbo.ice_hockey_action_plays AS plays  WITH (NOLOCK) 
		ON players.ice_hockey_action_play_id = plays.id
	INNER JOIN dbo.ice_hockey_event_states AS event_states   WITH (NOLOCK) 
		ON plays.ice_hockey_event_state_id = event_states.id
	INNER JOIN dbo.events AS e  WITH (NOLOCK) 
		ON event_states.event_id = e.id
	INNER JOIN dbo.display_names AS player_names   WITH (NOLOCK) 
		ON players.person_id = player_names.entity_id
	INNER JOIN dbo.display_names AS team_names   WITH (NOLOCK) 
		ON plays.team_id = team_names.entity_id
	INNER JOIN dbo.persons WITH (NOLOCK) 
		ON players.person_id = persons.id
	INNER JOIN dbo.teams  WITH (NOLOCK) 
		ON plays.team_id = teams.id

	WHERE	player_names.entity_type = 'persons'
	AND		team_names.entity_type = 'teams'
	AND		plays.score_attempt_type IS NOT NULL 
	AND		players.participant_role = 'scorer'
	AND		e.publisher_id IN (SELECT MAX(id) FROM dbo.publishers WHERE publisher_key = 'sportsnetwork.com');

GO
