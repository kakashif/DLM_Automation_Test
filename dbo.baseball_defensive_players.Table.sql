USE [SportsDB]
GO
/****** Object:  Table [dbo].[baseball_defensive_players]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[baseball_defensive_players](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[baseball_defensive_group_id] [int] NOT NULL,
	[player_id] [int] NOT NULL,
	[position_id] [int] NOT NULL,
 CONSTRAINT [PK__baseball_defensi__4222D4EF] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
