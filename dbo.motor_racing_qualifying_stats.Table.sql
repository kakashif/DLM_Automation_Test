USE [SportsDB]
GO
/****** Object:  Table [dbo].[motor_racing_qualifying_stats]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[motor_racing_qualifying_stats](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[grid] [varchar](100) NULL,
	[pole_position] [varchar](100) NULL,
	[pole_wins] [varchar](100) NULL,
	[qualifying_speed] [varchar](100) NULL,
	[qualifying_speed_units] [varchar](100) NULL,
	[qualifying_time] [varchar](100) NULL,
	[qualifying_position] [varchar](100) NULL,
 CONSTRAINT [PK__motor_racing_qua__1332DBDC] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
