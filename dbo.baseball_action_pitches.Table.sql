USE [SportsDB]
GO
/****** Object:  Table [dbo].[baseball_action_pitches]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[baseball_action_pitches](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[baseball_action_play_id] [int] NOT NULL,
	[baseball_defensive_group_id] [int] NULL,
	[umpire_call] [varchar](100) NULL,
	[pitch_location] [varchar](100) NULL,
	[pitch_type] [varchar](100) NULL,
	[pitch_velocity] [int] NULL,
	[comment] [varchar](2048) NULL,
	[trajectory_coordinates] [varchar](512) NULL,
	[trajectory_formula] [varchar](100) NULL,
	[ball_type] [varchar](40) NULL,
	[strike_type] [varchar](40) NULL,
	[sequence_number] [decimal](4, 1) NULL,
	[strikes] [int] NULL,
	[balls] [int] NULL,
 CONSTRAINT [PK__baseball_action___3A81B327] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
