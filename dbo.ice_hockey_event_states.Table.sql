USE [SportsDB]
GO
/****** Object:  Table [dbo].[ice_hockey_event_states]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[ice_hockey_event_states](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[event_id] [int] NOT NULL,
	[current_state] [tinyint] NULL,
	[sequence_number] [varchar](100) NULL,
	[period_value] [varchar](100) NULL,
	[period_time_elapsed] [varchar](100) NULL,
	[period_time_remaining] [varchar](100) NULL,
	[context] [varchar](40) NULL,
	[play_id] [varchar](100) NULL,
	[record_type] [varchar](40) NULL,
	[power_play_team_id] [int] NULL,
	[power_play_player_advantage] [int] NULL,
	[score_team] [int] NULL,
	[score_team_opposing] [int] NULL,
	[score_team_home] [int] NULL,
	[score_team_away] [int] NULL,
	[action_key] [varchar](100) NULL,
	[document_id] [int] NULL,
 CONSTRAINT [PK__ice_hockey_event__7A672E12] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
ALTER TABLE [dbo].[ice_hockey_event_states]  WITH CHECK ADD  CONSTRAINT [FK_hockey_event_states_power_play_team_id_teams_id] FOREIGN KEY([power_play_team_id])
REFERENCES [dbo].[teams] ([id])
GO
ALTER TABLE [dbo].[ice_hockey_event_states] CHECK CONSTRAINT [FK_hockey_event_states_power_play_team_id_teams_id]
GO
