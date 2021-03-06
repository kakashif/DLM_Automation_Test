USE [SportsDB]
GO
/****** Object:  Table [dbo].[ice_hockey_action_plays]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[ice_hockey_action_plays](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[ice_hockey_event_state_id] [int] NOT NULL,
	[play_type] [varchar](100) NULL,
	[score_attempt_type] [varchar](100) NULL,
	[play_result] [varchar](100) NULL,
	[comment] [varchar](1024) NULL,
	[penalty_type] [varchar](100) NULL,
	[penalty_length] [varchar](100) NULL,
	[penalty_code] [varchar](100) NULL,
	[recipient_type] [varchar](100) NULL,
	[team_id] [int] NULL,
	[strength] [varchar](100) NULL,
	[shootout_shot_order] [int] NULL,
	[goal_order] [int] NULL,
	[shot_type] [varchar](100) NULL,
	[shot_distance] [varchar](100) NULL,
	[goal_zone] [varchar](100) NULL,
	[penalty_time_remaining] [varchar](40) NULL,
	[location] [varchar](40) NULL,
	[zone] [varchar](40) NULL,
 CONSTRAINT [PK__ice_hockey_actio__7C4F7684] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
