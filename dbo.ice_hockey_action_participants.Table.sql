USE [SportsDB]
GO
/****** Object:  Table [dbo].[ice_hockey_action_participants]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[ice_hockey_action_participants](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[ice_hockey_action_play_id] [int] NOT NULL,
	[person_id] [int] NOT NULL,
	[participant_role] [varchar](100) NULL,
	[point_credit] [int] NULL,
	[team_id] [int] NULL,
	[goals_cumulative] [int] NULL,
	[assists_cumulative] [int] NULL,
 CONSTRAINT [PK__ice_hockey_actio__7E37BEF6] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
ALTER TABLE [dbo].[ice_hockey_action_participants]  WITH CHECK ADD  CONSTRAINT [FK_ice_hockey_action_participants_team_id_teams_id] FOREIGN KEY([team_id])
REFERENCES [dbo].[teams] ([id])
GO
ALTER TABLE [dbo].[ice_hockey_action_participants] CHECK CONSTRAINT [FK_ice_hockey_action_participants_team_id_teams_id]
GO
